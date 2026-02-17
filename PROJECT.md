# PROJECT.md — ralph-runs

This document is for AI agents working in this codebase. It explains what this project is, how everything fits together, and what you need to know to make changes effectively.

## What This Project Is

ralph-runs is an autonomous software development pipeline. It continuously polls for queued development goals, spawns AI agents (called "ralphs") to execute them in isolated repository clones, creates pull requests from the results, and handles retries on failure. The system manages the full lifecycle from goal creation through PR merge.

The project philosophy is deliberately minimalist: small, focused scripts in Ruby that coordinate through a shared REST API and the filesystem. When something breaks, there's not much code to debug.

## System Architecture

ralph-runs is one piece of a multi-service system. The services are:

| Service | Language | Port | Purpose |
|---------|----------|------|---------|
| **ralph-plans** | Go + SQLite | 5001 | Goal storage and state machine (the central database) |
| **ralph-shows** | — | 5000 | Web UI |
| **ralph-runs** | Ruby | 5002 | This project — orchestrator + agent loop |
| **ralph-logs** | Go | 5003 | WebSocket-based real-time log streaming |
| **ralph-counts** | Python | 5004 | Metrics dashboard (completion rates, costs, token usage) |

This project (ralph-runs) contains the orchestrator, the agent loop, and all goal management CLI scripts. The other services are separate repositories.

## How It Works End-to-End

```
Human authors goal markdown
        ↓
goal-create → goal stored in ralph-plans (status: draft)
        ↓
goal-queue → status: queued
        ↓
ralph-runs polling loop (every 5s) picks it up
        ↓
goal-start → status: running (atomic, race-safe)
        ↓
git clone → jj init → write goal to .pipeline/cache/goal.md
        ↓
spawn ralph (the agent loop) in the clone
        ↓
ralph iterates: prompt Claude → execute tools → record progress → jj commit
        ↓
ralph exits 0 (success) or non-zero (failure)
        ↓
Success: create PR → auto-merge → goal-submitted
Failure: post comment → goal-stuck → goal-retry (up to 3 retries)
```

## Directory Structure

```
ralph-runs/
├── bin/                          # Symlinks to scripts (added to PATH via .envrc)
│   ├── ralph-runs → ../scripts/ralph-runs/run
│   ├── ralph → ../scripts/ralph/run
│   ├── goal-create → ../scripts/goal-create/run
│   ├── goal-list → ../scripts/goal-list/run
│   ├── goal-get → ../scripts/goal-get/run
│   ├── goal-queue → ../scripts/goal-queue/run
│   ├── goal-start → ../scripts/goal-start/run
│   ├── goal-submitted → ../scripts/goal-submitted/run
│   ├── goal-stuck → ../scripts/goal-stuck/run
│   ├── goal-retry → ../scripts/goal-retry/run
│   ├── goal-comment → ../scripts/goal-comment/run
│   ├── goal-comments → ../scripts/goal-comments/run
│   ├── goal-cancel → ../scripts/goal-cancel/run
│   ├── notify → ../scripts/notify/run
│   └── reset-repo → ../.claude/scripts/reset-repo
├── scripts/                      # All executable scripts (Ruby)
│   ├── ralph-runs/run            # The orchestrator (~590 lines)
│   ├── ralph/                    # The agent loop
│   │   ├── run                   # Main agent loop (~1380 lines)
│   │   ├── prompt.md.erb         # ERB template for worker prompts
│   │   ├── summarizer.md.erb     # ERB template for progress summarization
│   │   ├── ralph.ascii           # ASCII art startup banner
│   │   └── COPYING.md            # Instructions for copying ralph to other projects
│   ├── goal-*/run                # Goal state management scripts
│   ├── goal-cancel/run           # Cancel a non-terminal goal
│   └── notify/run                # ntfy.sh push notification sender
├── .claude/
│   ├── library/                  # Skill documents (loaded via /load)
│   │   ├── jj/SKILL.md           # Jujutsu VCS workflow
│   │   ├── pipeline/SKILL.md     # Goal commands and pipeline workflow
│   │   └── goal-authoring/SKILL.md  # How to write effective goals
│   ├── skillsets/                 # Composite skill bundles (loaded via /skillset)
│   │   ├── meta.json             # For improving .claude/ itself (jj + pipeline + goal-authoring)
│   │   ├── ralph-preloads.json   # Skills injected into ralph's prompt (jj)
│   │   └── ralph-recommends.json # Skills advertised to ralph by name only (empty)
│   └── commands/                 # Custom Claude Code commands
│       ├── load.md               # /load command implementation
│       └── skillset.md           # /skillset command implementation
├── launch.sh                     # Entry point: runs ralph-runs --max=2 across 4 repos
├── .envrc                        # direnv config: PATH, SSH key, service host/port vars
├── CLAUDE.md                     # Claude Code project instructions
└── PROJECT.md                    # This file
```

## The Two Core Scripts

### `scripts/ralph-runs/run` — The Orchestrator

This is the outer loop. It manages concurrency, goal lifecycle, cloning, PR creation, and retries.

**What it does each cycle (every 5 seconds):**

1. **Check for shutdown** (Ctrl+C) — gracefully kills running ralphs, requeues their goals
2. **Collect finished ralphs** — checks PIDs for completed processes
3. **Handle results:**
   - Exit 0: commit remaining changes, create jj bookmark `goal-<id>`, push, create PR via `gh`, auto-merge
   - Exit non-zero: post failure comment to goal, mark stuck, requeue (up to 3 retries), notify on exhaustion
4. **Fill open slots** — fetch queued goals across all repos, prioritize untried over retried (fairness), clone repo, write goal body, spawn ralph

**Key design decisions:**
- `goal-start` is atomic/race-safe — if two orchestrators try to claim the same goal, only one succeeds
- Each goal gets a completely isolated git clone at `~/.local/state/ralph/clones/<org>/<repo>/<goal_id>/`
- Retry context is built by fetching previous comments and appending them to the goal body
- Log streaming uses `Open3.popen2e` with a background thread per ralph

**CLI:**
```
ralph-runs --max N [--model MODEL] [--reasoning LEVEL] [--duration DURATION] REPO_URL [REPO_URL ...]
```

### `scripts/ralph/run` — The Agent Loop

This is the inner loop. It executes a single goal by iterating Claude invocations until the work is done or time runs out.

**Each iteration:**

1. Build prompt from ERB template: goal + summary of prior work + recent iteration progress + loaded skills
2. Invoke Claude via CLI with tools (Read, Write, Edit, Glob, Grep, Bash, Skill, StructuredOutput) and extended thinking
3. Stream and parse the response (tool calls, text blocks, thinking blocks)
4. Extract structured output: `{"summary": "what I did"}` or `{"summary": "DONE"}`
5. Append progress to `goal-progress.jsonl`
6. Commit iteration via `jj commit -m "ralph: iteration N"` (excludes runtime files)
7. Every ~5 iterations, invoke a summarizer to condense progress history

**Context management is critical.** Ralph has a 200K token context window. The summarizer prevents unbounded growth by compressing older iterations into a narrative summary while preserving failed approaches, key decisions, and current state.

**Extended thinking** is configurable by model and reasoning level:
- Budget = model_max * reasoning_multiplier
- Models: haiku (16K max), sonnet (32K max), opus (16K max)
- Levels: none (0x), low (0.25x), med (0.5x), high (1x)

**Cost tracking** is built in, with per-model pricing and cache savings calculations.

**Termination conditions:**
- Structured output contains `"DONE"` → exit 0
- Duration timeout → exit 0
- Context exhaustion or crash → exit non-zero

## Goal State Machine

```
draft ──→ queued ──→ running ──→ submitted ──→ merged
  │         │          │                    └──→ rejected
  │         │          └──→ stuck ──→ queued (via retry)
  │         │
  └─────────┴──→ cancelled (via goal-cancel, any non-terminal state)
```

## Goal Management Scripts

All scripts interact with the ralph-plans API over HTTP. All return JSON with `{"ok": true/false, ...}`.

| Script | Usage | Purpose |
|--------|-------|---------|
| `goal-create` | `--title "..." --org ORG --repo REPO < body.md` | Create goal (draft). Body via stdin. |
| `goal-list` | `[--status STATUS] [--org ORG] [--repo REPO]` | List goals, optionally filtered |
| `goal-get` | `<id>` | Fetch full goal (id, org, repo, title, body, status, timestamps) |
| `goal-queue` | `<id>` | draft → queued |
| `goal-start` | `<id>` | queued → running (atomic, fails if already claimed) |
| `goal-submitted` | `<id>` | running → submitted |
| `goal-stuck` | `<id>` | running → stuck |
| `goal-retry` | `<id>` | stuck → queued |
| `goal-comment` | `<id> < comment.txt` | Append comment (body via stdin) |
| `goal-comments` | `<id>` | List comments with timestamps |
| `goal-cancel` | `<id>` | Cancel a non-terminal goal |
| `notify` | `< {"title":"...","message":"..."}` | Send push notification via ntfy.sh |

## Goal File Format

Goals are markdown files with this structure:

```markdown
## Objective
What should be accomplished. Specify WHAT, not HOW.

## Reference
Relevant files, docs, and examples. Be comprehensive — ralph reads across iterations.

## Outcomes
Measurable, verifiable results.

## Acceptance
Success criteria (e.g., "all tests pass", specific commands that must succeed).
```

**Key authoring principles:**
- Specify outcomes, not steps — ralph discovers the path through iteration
- Reference liberally — ralph has unlimited context through iteration
- Make discovery explicit — "Discover and fix all X" not just "Fix X"
- Include measurable acceptance criteria — ralph needs to know when it's done

## Version Control

This project uses **Jujutsu (jj)** instead of git. Key differences:

- Commits are created with `jj commit -m "msg"` (not git commit)
- Branches are called "bookmarks" (`jj bookmark create/set/track`)
- Remote tracking uses `main@origin` syntax
- Working copy (`@`) is always a commit being edited
- Remote commits are immutable — use `jj restore` instead of `jj rebase` for remote branches

The orchestrator creates one bookmark per goal (`goal-<id>`) on HEAD of the commit stack, then pushes the entire stack.

## Environment

Configured via `.envrc` (direnv):

- `PATH` includes `bin/` for direct script access
- `GIT_SSH_COMMAND` points to a specific SSH key
- `RALPH_PLANS_HOST/PORT` (localhost:5001) — goal storage API
- `RALPH_SHOWS_HOST/PORT` (localhost:5000) — web UI
- `RALPH_RUNS_HOST/PORT` (localhost:5002) — this service
- `RALPH_LOGS_HOST/PORT` (localhost:5003) — log streaming
- `RALPH_COUNTS_HOST/PORT` (localhost:5004) — metrics

Optional notification variables: `NTFY_TOPIC`, `NTFY_API_KEY`

## Runtime Filesystem

At runtime, ralph-runs creates state under `~/.local/state/ralph/`:

```
~/.local/state/ralph/
├── clones/<org>/<repo>/<goal_id>/    # Isolated repo clones (one per goal)
│   └── .pipeline/cache/
│       ├── goal.md                    # The goal being executed
│       └── ralph.log                  # Ralph's log output
└── logs/
    └── ralph-runs.log                 # Orchestrator log
```

## Skillsets and Skills

The `.claude/` directory implements a modular instruction system:

- **Skills** are markdown documents in `.claude/library/<name>/SKILL.md` loaded via `/load <name>`
- **Skillsets** are JSON bundles in `.claude/skillsets/<name>.json` loaded via `/skillset <name>`
- Skillsets define `preload` (loaded immediately) and `advertise` (available on demand) arrays

Three skillsets exist:
- **meta** — for modifying the .claude/ system itself (loads jj + pipeline + goal-authoring)
- **ralph-preloads** — skills injected into ralph's prompt (jj)
- **ralph-recommends** — skills advertised to ralph by name/description only (empty)

## Dependencies

- **Ruby** (3.x) — all scripts
- **jj (Jujutsu)** — version control
- **Claude Code CLI** (`claude` command) — invoked by ralph for each iteration
- **GitHub CLI** (`gh` command) — PR creation and management
- **direnv** — environment management (optional but expected)
- **ralph-plans API** — must be running on configured host:port

## Common Tasks When Modifying This Project

**Adding a new goal command:** Create `scripts/<name>/run` (Ruby, returns JSON), symlink from `bin/<name>`, add corresponding constant in `scripts/ralph-runs/run`.

**Changing ralph's prompt:** Edit `scripts/ralph/prompt.md.erb`. Available ERB variables: `goal`, `summary`, `summary_end`, `recent`, `skills`, `advertised_skills`, `pull_request`, `branch_name`.

**Changing the summarizer:** Edit `scripts/ralph/summarizer.md.erb`. Variables: `summary`, `summary_end`, `current`, `recent`.

**Adding a skill:** Create `.claude/library/<name>/SKILL.md` with YAML frontmatter (name, description). Add to relevant skillset JSON files.

**Changing retry behavior:** `MAX_RETRIES` constant in `scripts/ralph-runs/run` (currently 3).

**Changing concurrency:** `--max N` flag to ralph-runs, or edit `launch.sh`.

**Changing the model or reasoning:** `--model` and `--reasoning` flags to ralph-runs. Thinking budgets are defined in `scripts/ralph/run` in the `THINKING_BUDGETS` and `REASONING_MULTIPLIERS` hashes.

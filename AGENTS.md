# ralph-runs

Autonomous software development pipeline orchestrator. Polls for queued goals from the ralph-plans API, spawns AI agents ("ralphs") to execute them in isolated repository clones, and creates pull requests from the results. Handles concurrency, retries (up to 3 attempts with failure context), and review workflows.

Philosophy: deliberately minimalist. Small, focused Ruby scripts coordinating through a REST API and the filesystem.

## Architecture

Part of a multi-service system:

| Service | Language | Port | Purpose |
|---------|----------|------|---------|
| **ralph-plans** | Go + SQLite | 5001 | Goal storage and state machine |
| **ralph-shows** | — | 5000 | Web UI |
| **ralph-runs** | Ruby | 5002 | This project — orchestrator + agent loop |
| **ralph-logs** | Go | 5003 | Real-time log streaming |
| **ralph-counts** | Python | 5004 | Metrics dashboard |

This project contains the orchestrator, the agent loop, and all goal management CLI scripts. Other services are separate repositories.

### End-to-End Flow

```
goal-create (draft) → goal-queue (queued) → orchestrator picks up →
  clone repo → spawn ralph → iterate until done → create PR → goal-done
```

Failures: comment posted → goal-stuck → goal-retry (up to 3 attempts).

### Core Scripts

| Script | Purpose |
|--------|---------|
| `scripts/ralph-runs/run` | Orchestrator — polling, concurrency, cloning, PR creation, retries (~590 lines) |
| `scripts/ralph/run` | Agent loop — iterates Claude invocations until goal complete (~1380 lines) |
| `scripts/ralph/prompt.md.erb` | Worker prompt template |
| `scripts/ralph/summarizer.md.erb` | Progress summarization template |
| `scripts/goal-*/run` | Goal state management scripts |
| `scripts/notify/run` | Push notifications via ntfy.sh |

### Goal State Machine

```
draft → queued → running → done
                    ├→ reviewing → done (approve) or queued (reject)
                    └→ stuck → queued (retry, up to 3x)
Any non-terminal state → cancelled (via goal-cancel)
```

## Development

### Version Control

This project uses **Jujutsu (jj)**, not git.

Key differences: `jj commit` not `git commit`, branches are "bookmarks", remote tracking uses `main@origin`, working copy (`@`) is always a commit being edited.

Full workflow: `.claude/library/jj/SKILL.md`

### Testing

No automated test suite. Validate changes by:

- Syntax check modified scripts: `ruby -c scripts/<name>/run`
- Running scripts with `--help` to verify argument parsing
- For the agent loop: test with a simple goal file and short `--duration`

### Code Style

- Ruby scripts, no gems beyond stdlib
- All goal scripts return JSON: `{"ok": true/false, ...}`
- Scripts live in `scripts/<name>/run`, symlinked from `bin/<name>`
- ERB templates for prompt generation
- Minimalist — small focused scripts, no abstractions for one-time operations

### Environment

Configured via `.envrc` (direnv). `PATH` includes `bin/` for direct script access. Services communicate via `RALPH_*_HOST/PORT` env vars. Optional: `NTFY_TOPIC`, `NTFY_API_KEY` for push notifications.

## Directory Structure

```
ralph-runs/
├── bin/                              # Symlinks to scripts (on PATH via .envrc)
├── scripts/
│   ├── ralph-runs/run                # Orchestrator
│   ├── ralph/
│   │   ├── run                       # Agent loop
│   │   ├── prompt.md.erb             # Worker prompt template
│   │   └── summarizer.md.erb         # Summarization template
│   ├── goal-*/run                    # Goal state management
│   └── notify/run                    # Notifications
├── .claude/
│   ├── library/                      # Skills (modular instruction sets)
│   └── skillsets/                    # Composite skill bundles
├── launch.sh                         # Entry point: runs ralph-runs across repos
├── .envrc                            # direnv config
└── AGENTS.md                         # This file
```

## Skills

Skills are modular instruction sets in `.claude/library/<name>/SKILL.md`.

- **Load a skill**: `/load <name>` reads the skill into context
- **Load multiple**: `/load name1 name2`

### Skillsets

Composite bundles in `.claude/skillsets/<name>.json`:

```json
{
  "preload": ["skill-a"],
  "advertise": [{"skill": "skill-b", "description": "When to use"}]
}
```

- `preload` — loaded immediately when skillset is activated
- `advertise` — shown as available, loaded on demand with `/load`

Available skillsets:

- `meta` — For improving the .claude/ system (preloads: jj, pipeline, goal-authoring)

### For Ralph

When Ralph executes a goal in this repo, it receives only `AGENTS.md` as project context. This file is responsible for getting Ralph everything it needs.

Load the ralph skillset at the start of work: `/skillset ralph`

## Goal Authoring

Goals are markdown files with required sections: `## Objective`, `## Reference`, `## Outcomes`, `## Acceptance`.

Key principles: specify WHAT not HOW, reference liberally, make discovery explicit, include measurable acceptance criteria, trust Ralph to iterate.

Full guide: `.claude/library/goal-authoring/SKILL.md`

## Common Tasks

**Changing ralph's prompt:** Edit `scripts/ralph/prompt.md.erb`. ERB variables: `goal`, `summary`, `summary_end`, `recent`, `agents_md`, `pull_request`, `branch_name`.

**Changing the summarizer:** Edit `scripts/ralph/summarizer.md.erb`. Variables: `summary`, `summary_end`, `current`, `recent`.

**Adding a skill:** Create `.claude/library/<name>/SKILL.md` with YAML frontmatter (name, description). Add to relevant skillset JSON.

**Adding a goal command:** Create `scripts/<name>/run` (Ruby, returns JSON), symlink from `bin/<name>`.

**Changing retry behavior:** `MAX_RETRIES` in `scripts/ralph-runs/run` (currently 3).

**Changing concurrency:** `--max N` flag to ralph-runs, or edit `launch.sh`.

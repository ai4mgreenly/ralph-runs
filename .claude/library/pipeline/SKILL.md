---
name: pipeline
description: Pipeline commands for managing goals
---

# Pipeline

Continuous development pipeline. Goals are executable units of work backed by the ralph-plans API (Go + SQLite). All scripts return JSON (`{"ok": true/false, ...}`).

Requires `RALPH_PLANS_HOST` and `RALPH_PLANS_PORT` environment variables.

## Flow

```
Goals (authored) → Queue → Ralph executes → PR merges
```

## Default Workflow: Goals-First

**The goals-first workflow is the default for all work.** Local changes are rare exceptions that require explicit user instruction.

**Standard workflow:**

1. **Discuss** - User and Claude discuss the change and approach
2. **Create goal** - Claude creates the goal with clear acceptance criteria
3. **Queue immediately** - Goal is queued right after creation (default behavior)
4. **Ralph executes** - User runs Ralph to execute the goal autonomously
5. **PR merges** - Completed work is merged via PR

**Default behaviors:**

- **Always queue after creation** - No manual testing or "trying it first" unless user explicitly requests it
- **No review** - Goals do not use `--review` flag unless user explicitly requests it during goal preparation
- **No local changes** - Claude does not make local changes directly; work goes through Ralph

**When to make local changes (exceptions only):**

- User explicitly requests direct changes: "make this change now", "edit this file", "fix this directly"
- User explicitly says: "don't create a goal for this", "do this locally", "make this change here"
- User specifies exceptions during goal preparation phase

**If unsure:** Default to creating and queuing a goal. The user will specify if they want an exception.

## Goal Statuses

`draft` → `queued` → `running` → `reviewing` or `done` (or `stuck`)

## Goal Commands

| Command | Usage | Does |
|---------|-------|------|
| `goal-create` | `--title "..." --org ORG --repo REPO [--review] < body.md` | Create goal (draft) |
| `goal-list` | `[--status STATUS] [--org ORG] [--repo REPO]` | List goals, optionally filtered |
| `goal-get` | `<id>` | Read goal body + status |
| `goal-queue` | `<id>` | Transition draft → queued |
| `goal-start` | `<id>` | Transition queued → running |
| `goal-done` | `<id>` | Transition running → done |
| `goal-stuck` | `<id>` | Transition running → stuck |
| `goal-retry` | `<id>` | Transition stuck → queued (requeue) |
| `goal-comment` | `<id> < comment.txt` | Append comment to goal (body via stdin) |
| `goal-comments` | `<id>` | List comments on a goal |
| `goal-spot-check` | `<id> set\|approve\|reject [--feedback "..."]` | Manage review state |

## Invocation

Scripts live in `scripts/<name>/run` with symlinks in `bin/`:

```bash
goal-list --status queued --org mgreenly --repo ikigai
goal-get 42
echo "## Objective\n..." | goal-create --title "Add X" --org mgreenly --repo ikigai
echo "## Objective\n..." | goal-create --title "Add X" --org mgreenly --repo ikigai --review
goal-queue 42
```

## Logs

- **Orchestrator log**: `~/.local/state/ralph/logs/ralph-runs.log`
- **Ralph logs**: `~/.local/state/ralph/clones/<org>/<repo>/<id>/.pipeline/cache/ralph.log`

## Goal Authoring

Goal bodies **must** follow the `goal-authoring` skill guidelines (`/load goal-authoring`). Key rules:

- Specify **WHAT**, never **HOW** — outcomes, not steps
- Reference relevant files — Ralph reads them across iterations
- Include measurable **acceptance criteria**
- Never pre-discover work (no specific line numbers or code snippets)
- Trust Ralph to iterate and discover the path

## Key Rules

- **Body via stdin** -- `goal-create` and `goal-comment` read body from stdin
- **IDs are global** -- Goal IDs are managed by ralph-plans, not GitHub issue numbers
- **--org / --repo flags** -- Use `--org ORG --repo REPO` (separate flags, not `OWNER/REPO`)
- **Review workflow** -- Goals created with `--review` go through `running → reviewing → done` (via `goal-spot-check set`, then `goal-spot-check approve`)
- **Retry workflow** -- Failed goals go `running → stuck → queued` (via `goal-stuck` then `goal-retry`); comments with failure context are attached automatically

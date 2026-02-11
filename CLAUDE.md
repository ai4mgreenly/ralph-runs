# ralph-runs

ralph-runs is an autonomous software development pipeline orchestrator. It polls for queued goals from the ralph-plans API, spawns AI agents ("ralphs") to execute them in isolated repository clones, and creates pull requests from the results. The orchestrator handles concurrency, retries (up to 3 attempts with failure context), and review workflows. The agent loop (`scripts/ralph/run`) iterates Claude invocations with extended thinking, progress tracking, and automatic summarization until the goal is done or time runs out. See `PROJECT.md` for full architectural details.

## Skills

Skills are modular instruction sets stored in `.claude/library/<name>/SKILL.md`.

- **Load a skill**: `/load <name>` reads the skill into context
- **Load multiple**: `/load name1 name2` loads several at once

## Skillsets

Skillsets are composite bundles of skills defined in `.claude/skillsets/<name>.json`.

- **Load a skillset**: `/skillset <name>` loads all preloaded skills and advertises on-demand ones
- **Skillset format**: JSON with `preload` (loaded immediately) and `advertise` (available via `/load`)

### Available skillsets

- `meta` - For improving the .claude/ system (jj)

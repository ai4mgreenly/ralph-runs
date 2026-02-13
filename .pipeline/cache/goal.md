## Objective

Stop writing any runtime files into repo clones. Currently ralph-runs writes goal files, progress files, summary files, and ralph logs into `clone_dir/.pipeline/cache/`, which pollutes the repo's working copy and causes merge conflicts in PRs. Move all of these to `RALPH_DIR/goals/<goal_id>/` instead.

## Reference

- `scripts/ralph-runs/run` — all the code that needs to change:
  - `ensure_pipeline_cache` (around line 106-115) — creates `.pipeline/cache/` in the clone and commits it. Remove entirely.
  - Goal file write (around line 492-495) — writes `goal.md` to `clone_dir/.pipeline/cache/`. Move to `RALPH_DIR/goals/<goal_id>/goal.md`.
  - Ralph log path (around line 489) — sets `ralph_log` to `clone_dir/.pipeline/cache/ralph.log`. Move to `RALPH_DIR/goals/<goal_id>/ralph.log`.
  - `--goal` argument (around line 502) — passes relative path `.pipeline/cache/goal.md`. Change to absolute path in RALPH_DIR.
  - `generate_pr_description` (around line 144-146) — reads `goal.md` and `goal-progress.jsonl` from `clone_dir/.pipeline/cache/`. Read from RALPH_DIR goals dir instead. Will need to accept or derive the goals dir path.
  - `create_pr_from_clone` — may need the goals dir path passed in to call `generate_pr_description`
  - Clone cleanup (around line 356, 366, 397) — add cleanup of `RALPH_DIR/goals/<goal_id>/` alongside clone deletion
  - The call to `ensure_pipeline_cache` (around line 134) — remove this call
  - Log message for ralph log path (around line 530) — update to reflect new location
- `scripts/ralph/run` lines 106-111 — `set_goal_paths` derives progress/summary paths from the goal file path. If `--goal` receives an absolute path in RALPH_DIR, all derived files automatically land there. No changes needed in ralph itself.

## Outcomes

- New constant `GOAL_DIR = File.join(RALPH_DIR, 'goals')` alongside existing `CLONE_DIR` and `LOG_DIR`
- `ensure_pipeline_cache` function removed entirely
- Goal file written to `RALPH_DIR/goals/<goal_id>/goal.md`
- Ralph log written to `RALPH_DIR/goals/<goal_id>/ralph.log`
- `--goal` flag passes the absolute path to the goal file in RALPH_DIR
- `generate_pr_description` reads goal and progress from `RALPH_DIR/goals/<goal_id>/`
- Goal dir cleaned up when clone is cleaned up (on done, stuck, or shutdown)
- No files are written to `.pipeline/cache/` in the clone at any point
- ralph-runs never calls `ensure_pipeline_cache` or creates `.pipeline/cache/` in clones

## Acceptance

- `ruby -c scripts/ralph-runs/run` passes
- grep for `.pipeline` in `scripts/ralph-runs/run` returns zero matches
- `GOAL_DIR` constant exists and is used for all runtime file paths
- Cleanup of `RALPH_DIR/goals/<goal_id>/` happens everywhere clone cleanup happens
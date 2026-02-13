## Objective

The `generate_pr_description` function invokes `claude -p` without clearing `ANTHROPIC_API_KEY`, which is inconsistent with how claude is invoked everywhere else in the codebase. Add `ANTHROPIC_API_KEY=` (empty) to the environment so it uses the system credential.

## Reference

- `scripts/ralph-runs/run` — `generate_pr_description` method, the `Open3.capture3` call (around line 173)
- `scripts/ralph/run` line 462-463 — the existing pattern: `ANTHROPIC_API_KEY= claude -p --model ...`

## Outcomes

- The `Open3.capture3` call in `generate_pr_description` passes `ANTHROPIC_API_KEY` as empty string in the environment, matching the pattern used in `scripts/ralph/run`
- For `Open3.capture3`, this means passing an env hash as the first argument: `Open3.capture3({'ANTHROPIC_API_KEY' => ''}, *cmd, stdin_data: prompt)`

## Acceptance

- `ruby -c scripts/ralph-runs/run` passes
- The capture3 call includes `{'ANTHROPIC_API_KEY' => ''}` as the env argument
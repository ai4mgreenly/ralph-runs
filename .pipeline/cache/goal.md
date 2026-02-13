## Objective

The `generate_pr_description` function silently swallows all errors via `rescue StandardError`. Add logging so we can diagnose why PR description generation is failing.

## Reference

- `scripts/ralph-runs/run` — `generate_pr_description` method, specifically the `rescue StandardError` clause (around line 182)
- The `log` method is available and writes to both stdout and the log file

## Outcomes

- The `rescue StandardError` clause captures the exception and logs it using the `log` method before returning nil
- Format: `log "PR description generation failed: #{e.class}: #{e.message}"` (where `e` is the rescued exception)

## Acceptance

- `ruby -c scripts/ralph-runs/run` passes
- The rescue clause uses `rescue StandardError => e` and calls `log` with the exception class and message
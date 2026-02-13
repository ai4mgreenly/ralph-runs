## Objective

Fix the `generate_pr_description` function in the orchestrator which blocks the main loop and uses an invalid JSON Schema, causing ralph-runs to hang after a ralph completes.

## Reference

- `scripts/ralph-runs/run` — `generate_pr_description` method (around line 143-175)
- The `claude` CLI accepts `--json-schema` with a valid JSON Schema object

## Outcomes

- The JSON Schema passed to `--json-schema` is a valid JSON Schema: `{"type":"object","properties":{"description":{"type":"string"}},"required":["description"]}`
- The `Open3.capture3` call has a timeout so it cannot block the orchestrator indefinitely. Use a simple approach: spawn the process, use `Timeout.timeout(60)` around the capture3 call (60 seconds is generous for a Haiku call). The existing `rescue StandardError` will catch `Timeout::Error` since it inherits from `RuntimeError`.
- The fallback behavior is preserved — if generation fails for any reason (timeout, bad output, exit code), return nil and the PR body falls back to `"Goal ##{goal_id}"`

## Acceptance

- `ruby -c scripts/ralph-runs/run` passes
- The JSON schema string is a valid JSON Schema with type, properties, and required fields
- The capture3 call is wrapped in a timeout
## Objective

Rewrite the claude invocation in `generate_pr_description` to match the working pattern used in `scripts/ralph/run`'s `invoke_claude` method. The current implementation uses `Open3.capture3` with an array command, which doesn't work. The existing codebase uses a shell command string with `IO.popen`.

## Reference

- `scripts/ralph-runs/run` — `generate_pr_description` method (around line 164-182), the broken invocation
- `scripts/ralph/run` lines 461-470 — the working pattern:
  ```ruby
  cmd = "ANTHROPIC_API_KEY= claude -p --model #{model} --output-format json --json-schema '#{schema}'"
  IO.popen(cmd, 'r+') do |io|
    io.write(prompt)
    io.close_write
    io.read
  end
  ```

## Outcomes

- The claude invocation in `generate_pr_description` uses a shell command string (not an array) with `IO.popen`, matching the pattern in `scripts/ralph/run`
- The command string includes `ANTHROPIC_API_KEY=` prefix (clearing the env var)
- Uses `--output-format json` for simple one-shot structured output
- Sends the rendered prompt via stdin using `IO.popen` in `r+` mode (write prompt, close_write, read response)
- Keeps the `Timeout.timeout(60)` wrapper around the IO.popen call
- Keeps the `rescue StandardError` fallback but adds logging: `log "PR description generation failed: #{e.class}: #{e.message}"`
- Parses the JSON response and extracts the `description` field (or `result` field, whatever claude returns)

## Acceptance

- `ruby -c scripts/ralph-runs/run` passes
- The invocation uses a shell command string with `IO.popen`, not `Open3.capture3`
- `ANTHROPIC_API_KEY=` is part of the command string prefix
- The rescue clause logs the error before returning nil
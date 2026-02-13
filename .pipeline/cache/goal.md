## Objective

Add AI-generated pull request descriptions to the orchestrator. When `create_pr_from_clone` creates a PR, it should first make a dedicated Claude call (Haiku model) that takes the goal body and all progress entries as context and produces a concise PR description describing the final result.

Currently the PR body is just `"Goal ##{goal_id}"`. Replace this with a generated description that tells reviewers what the PR delivers and why.

## Reference

- `scripts/ralph-runs/run` — orchestrator, specifically `create_pr_from_clone` (around line 141) where PRs are created with `gh pr create`
- `scripts/ralph/run` — agent loop, for understanding progress/goal file conventions:
  - Goal file: `.pipeline/cache/goal.md` (relative to clone dir)
  - Progress file: `.pipeline/cache/goal-progress.jsonl` — one JSON line per iteration with `{"iteration": N, "timestamp": "...", "progress": "summary string"}`
- `scripts/ralph/summarizer.md.erb` — existing summarizer template, as a pattern for ERB prompt templates
- `scripts/ralph/run` lines 461-463 — existing pattern for invoking `claude -p` with `--model`, `--json-schema`, and stream-json I/O

## Example

A good generated PR description looks like this:

```markdown
Adds AI-generated PR descriptions to the orchestrator. Instead of bare
"Goal #N" bodies, PRs now get a Haiku-generated summary describing what
the PR delivers and why, based on the goal and iteration progress.

- New ERB template for PR description prompt
- `generate_pr_description` function reads goal + progress, calls Haiku
- `create_pr_from_clone` uses generated body with fallback to "Goal #N"

Goal #6
```

Key qualities:
- **Describes the final result**, not the iteration history ("Added X" not "First I tried Y, then Z")
- **2-3 sentence summary** of what and why, then a short bullet list of key changes
- **No boilerplate** — no empty sections, no "N/A", no headers like "## Summary"
- **Developer voice** — reads like a human wrote it for a reviewer
- **Concise** — the whole thing fits in a glance

## Outcomes

- New ERB template `scripts/ralph-runs/pr-description.md.erb` that:
  - Embeds the full goal body as context
  - Embeds all progress entries (numbered by iteration) as context
  - Instructs the model to describe the FINAL RESULT — what the PR delivers — not a history of iterations
  - Instructs the model to write as a developer describing their own PR to a reviewer
  - Requests format: a short summary (2-3 sentences max) of what and why, followed by a bullet list of key changes
  - Emphasizes conciseness — no boilerplate, no padding, no "N/A" sections
  - Includes the example above as a reference for tone and format

- New function `generate_pr_description(clone_dir)` in the orchestrator that:
  - Reads `.pipeline/cache/goal.md` from the clone dir
  - Reads `.pipeline/cache/goal-progress.jsonl` from the clone dir (all entries)
  - Renders the ERB template with goal body and progress entries
  - Invokes `claude -p --model haiku` with a JSON schema `{"description": "string"}` to get the PR body
  - Returns the generated markdown string

- `create_pr_from_clone` updated to:
  - Call `generate_pr_description` before `gh pr create`
  - Use the generated description as the `--body` argument
  - Fall back to `"Goal ##{goal_id}"` if generation fails for any reason
  - Append `"Goal ##{goal_id}"` to the end of the generated description for traceability

## Acceptance

- `ruby -c scripts/ralph-runs/run` passes
- The ERB template renders without error when given a goal body string and an array of progress entry strings
- The `generate_pr_description` function handles missing/empty progress files gracefully (returns fallback)
- The `create_pr_from_clone` function still works end-to-end — PR creation does not break if description generation fails
- No gems beyond stdlib are introduced
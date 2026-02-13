## Objective

Prevent branch name collisions by making goal PR branch names unique per attempt. Currently `create_pr_from_clone` uses `goal-#{goal_id}` which collides if the branch already exists on the remote from a previous attempt or closed PR.

## Reference

- `scripts/ralph-runs/run` — `create_pr_from_clone` method, specifically the `branch = "goal-#{goal_id}"` line

## Outcomes

- Branch name format changed to `goal-#{goal_id}-#{Time.now.to_i.to_s(36)}` producing names like `goal-8-k1m2n3`
- Only the single line that assigns the `branch` variable needs to change
- No other logic changes — bookmark create, track, push, and `gh pr create --head` all use the `branch` variable already

## Acceptance

- `ruby -c scripts/ralph-runs/run` passes
- The branch name format includes the goal ID and a short base-36 timestamp suffix
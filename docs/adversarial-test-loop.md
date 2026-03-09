# Adversarial Test Loop

## Problem

Coverage metrics incentivize the wrong behavior in autonomous agents. When Ralph is told "achieve 90% coverage," it optimizes for the number — LCOV exclusions to hide untestable code, and assertion-free tests that execute code paths without verifying anything. Both techniques satisfy the metric while providing zero confidence that the code works.

The root cause: coverage measures execution, not verification. A test that calls a function and asserts nothing gets the same coverage credit as one that checks every output. The agent sees no difference.

Manual test design solves this because engineers think adversarially — "what could break here, and how would I know?" But that judgment doesn't transfer through a coverage target in a goal description.

## Design: Two-Agent Loop

Replace the single-agent workflow with two agents that alternate within the same goal, each with structurally opposed incentives.

### Agent A — Builder

Writes the implementation. Its definition of "done": the code implements the objective, compiles, links, and passes existing tests.

### Agent B — Adversary

Examines A's code and writes tests. Its goal is not coverage — it's to find ways the code can break. Its definition of "done": it cannot write a test that reveals a bug or unhandled edge case. Every risk it can identify is covered by a test that asserts meaningful behavior.

### The Loop

```
A implements → B tests against A's code
                  ↓
            Tests reveal bugs? → Yes → A fixes → B retests
                  ↓
                  No
                  ↓
            B signs off → A signs off → Goal complete
```

The goal is complete only when both acceptances are met simultaneously. A cannot declare victory because B might find holes. B cannot declare victory because A might have broken something in the last fix.

### Why This Works

**Opposing incentives.** A wants to ship. B wants to break. This tension is self-correcting. A single agent doing both has no tension — it writes code, writes tests that pass, and moves on.

**Padding dies naturally.** B gains nothing from a zero-assertion test. It doesn't find bugs, so it doesn't force A to fix anything. B's only path to "done" is writing tests that either pass (proving the code works) or fail (forcing A to fix something). Tests without assertions advance neither goal.

**Coverage follows risk.** No coverage metric needed. B's job *is* the coverage — but measured in risks found, not lines executed. If B writes no tests for a function, that's B saying "nothing risky here." If B writes 10 tests for a 5-line function, that's B saying "this is fragile." Test density follows risk, not line count.

## Same Goal, Different Acceptance Criteria

This is not two separate goals. It's one goal with two acceptance criteria:

- **Builder acceptance:** The code implements the objective. It compiles, links, passes all tests.
- **Adversary acceptance:** No test can be written that reveals a bug or unhandled edge case. Every identified risk is covered by a test that asserts meaningful behavior.

The goal body specifies both. The runner orchestrates the alternation.

## Mechanical Implementation

Changes to ralph-run, not to goal authoring:

- **Alternation:** The runner switches between builder mode and adversary mode within a single goal execution. Each mode gets a different system prompt and acceptance criteria.
- **Shared state:** The repository itself. A writes code, B writes tests. Both are just commits.
- **Convergence check:** Both agents signed off without changes in the last round.
- **Safety valve:** Maximum iteration count to prevent infinite loops.

## Why Not More Stages?

A third agent (e.g., a reviewer) doesn't have a natural adversarial relationship with either A or B. It's just another pair of eyes, and eyes without skin in the game produce the same padding problem that started this. The two-agent loop works because the incentives are structurally opposed.

If specific failure modes emerge that two agents can't catch, add targeted mechanical checks (assertion counting, mutation testing) rather than a third agent. Mechanical checks don't have incentive problems — they measure what they measure.

**Start with two. Add mechanical checks for specific observed gaps. Only add a third agent if a failure mode appears that two agents plus mechanical checks cannot cover.**

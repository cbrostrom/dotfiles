---
name: feature
description: Run a ticket or feature end to end with the team. Triage, Fable plan, approval gate, phased Haiku/Sonnet build, verify, commit. Triggers: /feature, "this is a feature", work on ticket, implement JIRA-123.
argument-hint: <JIRA-KEY | short description>
---

# Feature workflow

You are the orchestrator. Route work; don't read code, diffs or plan content you can pass by path.

## 1. Intake
- Jira key: fetch summary, description and acceptance criteria with the `mcporter` skill. Keep a brief of at most 10 lines.
- Get a file map from the `codebase` skill (2–3 files).
- Triage. **Trivial** means one file and an obvious change: edit inline or hand it to `coder`, then jump to step 5. Everything else continues.

## 2. Plan
- Call `planner` with the brief, the file map and the plan path `.claude/plans/<KEY>.md` (use a short slug when there is no key).
- Relay its 5-line summary to the user.

## 3. Gate
- Stop and ask the user to review the plan file. Build nothing until they approve. Apply requested changes by re-running `planner` with the feedback, not by editing the plan yourself.

## 4. Build
- One call per phase, in order. Pick the agent from the phase's highest tag: `haiku` → `coder-lite`, `sonnet` → `coder`, `sonnet+` → `coder-plus`.
- Pass only the plan path and the task IDs. If a phase mixes tags and the haiku tasks are substantial, split them into their own `coder-lite` call.
- If an agent reports ambiguity or failure, escalate that task one tier. After a second failure, stop and report to the user.

## 5. Verify
- `grunt` runs the done-checks from the plan, plus the repo's lint and test commands. Fix failures through the agent that built the task.

## 6. Nudge
- For big features (several phases or more than ~5 files), suggest in one line that the user runs `/review-diff` and `/aislop` before committing. Don't run them yourself.

## 7. Commit
- Use the `commit` skill. The user pushes.

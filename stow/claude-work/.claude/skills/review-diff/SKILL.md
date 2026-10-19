---
name: review-diff
description: "Manual review of the current diff by the reviewer agent (logic bugs, edge cases). Adds a security pass on request. User-invoked only."
argument-hint: "[base-ref] [security]"
disable-model-invocation: true
---

# Review the diff

1. Pick the range: the given base ref, else uncommitted changes, else `HEAD~1..HEAD`. Get the file list with `git diff --stat`; don't read the diff yourself.
2. Call `reviewer` with the range and the file list. Ask for findings ranked by severity, each with file:line and a one-line fix, at most 15 lines.
3. With the argument `security`, or when the diff touches auth, input handling or public endpoints, also call `ce-security-reviewer` the same way, after the first finishes.
4. Relay the findings. Fix nothing until the user says which to fix.

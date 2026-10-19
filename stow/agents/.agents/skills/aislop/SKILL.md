---
name: aislop
description: "Manual aislop quality pass: scan changed files, auto-fix mechanical findings, fix remaining errors, report the score. User-invoked only."
argument-hint: "[all]"
disable-model-invocation: true
---

# aislop pass

1. Scan: `aislop scan --changes`. With the argument `all`, run `aislop scan` on the whole project.
2. Nothing found: report the score in one line and stop.
3. Run `aislop fix` for the mechanical findings.
4. Fix the remaining `error` findings and `warning` findings marked fixable by hand. Follow `.aislop/rules.yaml` when a finding cites `architecture/*`.
5. Re-scan once. Never disable a rule or edit `.aislop/config.yaml` to pass.
6. Report: score before and after, what was fixed, and what was left with a one-line reason (false positive, needs a decision).

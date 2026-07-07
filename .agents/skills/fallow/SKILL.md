---
name: fallow
description: Codebase intelligence for JavaScript and TypeScript. Free static layer reports quality, changed-code risk, cleanup opportunities (unused files, exports, types, dependencies), code duplication, circular dependencies, complexity hotspots, architecture boundary violations, feature flag patterns, and opt-in security candidates. Use when asked to analyze code health, audit PR risk, find cleanup opportunities or unused code, detect duplicates, check circular deps, audit complexity, surface security candidates, or run fallow.
license: MIT
metadata:
  author: Bart Waardenburg
  homepage: https://docs.fallow.tools
---

# Fallow

Full docs: https://docs.fallow.tools

## Install

```bash
npm install -g fallow
npx fallow dead-code   # run without installing
```

## Agent rules

1. **Always use `--format json --quiet 2>/dev/null`** — discards stderr so progress messages don't corrupt JSON on stdout. Never use `2>&1`.
2. **Always append `|| true`** — exit code 1 means "issues found" (normal), not a runtime error.
3. **Always `--dry-run` before `fix`**, then `fix --yes` to apply (required in non-TTY).
4. **Never run `fallow watch`** — interactive, never exits.
5. **Never enable telemetry on the user's behalf** — it's opt-in and off by default.

## Task cheat sheet

| Intent | Command |
|---|---|
| Delete an "unused" export or file | `fallow dead-code --trace <file>:<export>` |
| Delete an "unused" dependency | `fallow dead-code --trace-dependency <name>` |
| Commit or open a PR | `fallow audit --base <ref>` |
| Prioritize refactoring | `fallow health --hotspots --targets` |
| Check untested-but-reachable code | `fallow health --coverage-gaps` |
| Consolidate duplication | `fallow dupes --trace dup:<fingerprint>` |
| Find feature flags | `fallow flags` |
| Surface security candidates | `fallow security` |
| Understand a finding | `fallow explain <issue-type>` |

## Instructions

1. Identify the task from the user's request (audit, fix, find dupes, set up CI, migrate, debug).
2. Run the appropriate command with `--format json --quiet`.
3. Use filter flags to limit output when the user asks about specific issue types.
4. Always dry-run before fix. Show the user what will change, then apply.
5. Report results clearly — summarize issue counts, list specific findings, suggest next steps.
6. For false positives, suggest inline suppression comments or config rule adjustments.

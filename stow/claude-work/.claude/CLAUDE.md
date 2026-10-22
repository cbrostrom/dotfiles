# Claude Code

Claude and pi share this machine. Claude works in any directory. Pi owns `~/.pi` and the vaults; pi-shared config changes go through `~/dotfiles`, and pi must not drift from Claude.

## Conventions
- English for code, comments and commits. Dates DD-MM-YYYY, timezone CET. Shell is zsh.
- Never run `git push`, `gh release`, `npm publish` or similar. Hooks block them; the user runs them.
- Never print secrets or .env values.
- Outline the plan and wait for confirmation before edits or mutating commands unless told to proceed.
- Prose follows the `writing` skill.

## Token mantra
- Every token must change the outcome. Do the cheapest step that answers the question.
- Grep or Glob before Read, read with offset/limit, never re-read a file. rtk compresses shell output; don't pipe through extra filters to save tokens.
- Stop once there is enough evidence to act. If two attempts fail, report instead of looping.
- Answers are short: no preamble, no restating the task, no recap of the obvious.

## Cache rules
- Don't switch models, toggle MCP servers or plugins, or edit CLAUDE.md or settings mid-session. Start a new session for those.
- Put work that would bloat the context on a subagent rather than doing it inline.

## Team protocol
- Feature and ticket work runs through `/feature`. The main session orchestrates and never reads code or plan content it can pass by path.
- Triage first. Trivial work (one file, obvious change) is done inline or by `coder`. Anything multi-file or unclear goes to `planner` (Fable), which writes `.claude/plans/<KEY>.md` with phases and a model tag per task.
- Build per phase, one call per phase: `coder-lite` (Haiku) for tasks the plan spells out exactly, `coder` (Sonnet) for normal tasks, `coder-plus` for non-trivial logic. Pass the plan path and task IDs.
- Lookups, logs, tests and builds go to `grunt`.
- At most two team agents at once (background allowed, only when the user asked for the work). Each delegation expects at most ~15 lines back.
- Repo override: if the repo defines `.claude/agents/` or a `Team protocol` in AGENTS.md, that takes precedence there. Any other agent runs on Haiku and is capped.

## Tools
- Jira, Confluence, Shopify docs: use the `mcporter` skill (`mw` wrapper). No MCP servers are registered.
- context-mode is deliberately off in Claude and pi; rtk and Higgins cover output compression and session memory.
- Review and quality passes are manual: `/review-diff`, `/aislop`, `/simplify` and `code-cleaner`. Suggest them at the end of big features; never run them unasked.

## Guards you will meet
Hooks and settings enforce billing, subagent model, secrets and push policy. If one blocks you, report it and stop; do not look for a way around it.

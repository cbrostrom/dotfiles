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
- Grep or Glob before Read, read with offset/limit, never re-read a file. Large or analytic output goes through `ctx_*` tools.
- Stop once there is enough evidence to act. If two attempts fail, report instead of looping.
- Answers are short: no preamble, no restating the task, no recap of the obvious.

## Cache rules
- Don't switch models, toggle MCP servers or plugins, or edit CLAUDE.md or settings mid-session. Start a new session for those.
- Put work that would bloat the context on a subagent rather than doing it inline.

## Team protocol
- The main session orchestrates: lookups, logs and tests go to `grunt`; implementation to `coder` (`coder-plus` for non-trivial logic or several files); only hard design or root-cause work to `planner`.
- One task in flight at a time. Each delegation states goal, files and done criteria, and expects at most ~15 lines back.
- Do a single small edit inline; delegating costs more.
- Repo override: if the repo defines `.claude/agents/` or a `Team protocol` in AGENTS.md, that takes precedence there. Any other agent runs on Haiku and is capped.

## Tools
- Jira, Confluence, Shopify docs: use the `mcporter` skill (`mw` wrapper). No MCP servers are registered.

## Guards you will meet
Hooks and settings enforce billing, subagent model, secrets and push policy. If one blocks you, report it and stop; do not look for a way around it.

# Claude Code

Claude and pi share this machine. Claude works in any directory. Pi owns `~/.pi` and the vaults; pi-shared config changes go through `~/dotfiles`, and pi must not drift from Claude.

## Conventions
- English for code, comments and commits. Dates DD-MM-YYYY, timezone CET. Shell is zsh.
- Never run `git push`, `gh release`, `npm publish` or similar. Hooks block them; the user runs them.
- Never print secrets or .env values.
- Outline the plan and wait for confirmation before edits or mutating commands unless told to proceed.
- Prose follows the `writing` skill.

## Tokens
- Large output goes through `ctx_*` tools. Grep before reading; read with offset/limit.
- No subagents unless asked. When used they run on a forced small model and are capped.

## Tools
- Jira, Confluence, Shopify docs: use the `mcporter` skill (`mw` wrapper). No MCP servers are registered.

## Guards you will meet
Hooks and settings enforce billing, subagent model, secrets and push policy. If one blocks you, report it and stop; do not look for a way around it.

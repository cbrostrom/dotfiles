@RTK.md
@agent-style/claude-code.md

# Commit messages
- Never append `Co-Authored-By: Claude` (or any Claude co-author trailer) to commit messages. Personal preference, applies in every repo.

# Push / publish whitelist
- Claude must NOT run `git push`, `gh release create`, `gh pr merge`, `npm publish`, `pnpm publish`, `cargo publish`, or similar publishing commands unless the current working directory is listed in `~/.claude/push-whitelist.txt` (one path per line, supports `~`).
- Customer / client repos (anything under `~/Projects/Clients`, `~/Projects/Shopify`, `~/Projects/Internal`, `~/Work`, etc.) must never be added to the whitelist. If a push is needed there, ask the user to do it manually.
- Enforcement lives in `~/.claude/hooks/git-push-guard.sh` (PreToolUse:Bash). The hook denies by default; treat a denial as the correct outcome and stop — do not retry, force, or work around it.
- To opt a personal repo in: append its path to `~/.claude/push-whitelist.txt`. Mention this to the user before doing it.

# Memory (Engram)

Two vaults on SuperBro VPS, accessed via SSH MCP (Tailscale). Both available as MCP tools in every session.

- `engram-personal` — all projects (personal + work). Default vault. Use for everything.
- `engram-work` — `stellar-shopify` only. Use when working in that project. Safe to share with AKQA colleagues.

Rules:
- Call `mem_context` at session start to load prior context.
- Use `mem_save` proactively — decisions, bugs, conventions, discoveries. Do not wait to be asked.
- Use `engram-work` tools when cwd is inside the stellar-shopify project. Use `engram-personal` everywhere else.
- Call `mem_session_summary` before ending a session.
- Prefer `mem_save` over writing to CLAUDE.md files for session-specific facts.

MCP servers registered via `~/.dotfiles/.claude/mcp-servers.list` — auto-installed on bootstrap.

# graphify
- **graphify** (`~/.claude/skills/graphify/SKILL.md`) - any input to knowledge graph. Trigger: `/graphify`
When the user types `/graphify`, invoke the Skill tool with `skill: "graphify"` before doing anything else.

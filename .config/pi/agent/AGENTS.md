# PI Agent Policy

PI is a harness. The policy lives in dotfiles.

## Source of truth

Read `~/dotfiles/AGENTS.md` before acting. That file is the authoritative policy
spine for all agents (Claude Code, Cursor, PI, Codex, Zed, Gemini, etc.).
This file is the PI adapter: it adds only what is PI-specific.

The key rules from dotfiles/AGENTS.md that apply here:
- Advisor stance, not assistant. Challenge gaps before executing.
- Approval gate: outline + wait before edits or mutating commands (unless user says auto/proceed/full go).
- Push/publish guard: never `git push`, `gh release create`, `npm publish`, etc.
- English default. Code, comments, commits always English.
- Coding principles: simplicity, surgical changes, build ladder (ponytail).

## Memory (Higgins)

CLI: `kb` (in PATH via `~/.local/bin/kb`); `~/dotfiles/scripts/brain` is a shim that execs `kb`.
Vault: `~/Vaults/Higgins/AI` (macOS, git-backed) — tier map: `personal/`, `modules/`, `projects/`, `infra/`, `sessions/`, `_ops/`

**MCP server (v2)**: kb-mcp running on superbro at `http://100.100.1.50:8765/mcp` (Tailscale-accessible).
- Chunked output at section boundaries
- Personal context cached (1hr TTL)
- Token budget enforced (default 2000, customizable)
- Tier hints: `kb_search("tier:personal ...")` for narrowing scope

**Never auto-call `kb_load()` at session start.** Vault lookups go through `kb_search` (live BM25 via kb-mcp) — no context load needed. `ctx_search` covers session/event memory (auto-captured events + indexed docs), not the vault.
Use `kb_load` or `kb_search` only when the user explicitly asks or a task clearly requires personal/project context.

For targeted lookups:
```
kb_search("<3-5 specific technical terms>")  # avoid vague queries
```

See `~/dotfiles/.agents/skills/kb/SKILL.md` for full MCP tool reference and tiered loading protocol.

Signals:
- `.remember` / `.r` — run `kb digest` (scans recent sessions, auto-prunes, proposes gotchas/current updates)
- `.note <text>` / `.n <text>` — `kb current "<text>"`
- `.gotcha <text>` / `.g <text>` — `kb gotcha "<text>"`

Key `kb` commands:
```bash
kb                     # dashboard for current slug
kb load [slug]         # inject brain context into session
kb current "<fact>"    # append to current.md (≤5 bullets enforced)
kb next "<action>"     # append to next.md
kb gotcha "<trap>"     # append to gotchas.md
kb prune [slug]        # move [done:] items → history/
kb compact [slug]      # cap current.md at 5 bullets, overflow → history/
kb digest [slug]       # scan sessions + propose updates (auto-runs prune+compact)
kb lint                # validate vault against _schema/
```

### Higgins Workflow Integration
- **Ralph-Wiggum**: During the "Reflection" phase of a `ralph` loop, ALWAYS update the project brain via `kb current` or `kb next` to persist progress across potential session resets.
- **Pi-Compound**: When compounding a solution, write the final pattern to the appropriate Higgins module (`modules/<name>/patterns.md`) or project brain (`projects/<slug>/gotchas.md`) rather than generic docs.

## Skills

Shared skills live in `~/.agents/skills/`. PI discovers these automatically.
Use `/skill:<name>` to load and run a skill.

Key shared skills available: `dotfiles`, `kb`, `code-reviewer`, `problem-solver`,
`standup`, `morning-brief`, `dot-doctor`, `jira-assistant`,
`code-cleaner`, `shopify`, `pi` (PI-specific daily-driver reference).

## PI-specific

- See `~/.config/pi/agent/README.md` for full architecture and package list.
- Model selection: use spark presets via `/preset`. Default model = `opencode/big-pickle` (free zen proxy, $0 — daily driver).
  `fast` (gpt-5.4-mini) for shell/edits, `sonnet` (cursor/default Auto) for regular work, `think` (claude-sonnet-4-6) for planning/review.
- Memory pipeline — three complementary layers, one brain:
  1. `pi-observational-memory` — in-session working memory. Captures observations + reflections
     in the background; makes compaction fast and preserves decision rationale across compactions.
     Ephemeral working state (per session/branch), never durable truth. Config under
     `observational-memory` in settings.json; workers use github-copilot/claude-haiku-4.5.
  2. `pi-rtk-optimizer` — output compaction + source filtering (zero-token).
  3. `context-mode` — machine-local FTS5 retrieval index (`~/.pi/context-mode/`, NOT synced,
     NOT human-editable). Fast cross-session search over auto-captured events + indexed docs on
     THIS machine. An accelerator, not the brain.
  4. `/session-extract` EOD — distils session signal (OM reflections first, context-mode events
     as fallback) into vault Markdown candidates; human-gated `kb digest` writes to Higgins.
  The durable, portable, human+AI-editable brain is the Higgins vault (`kb` + kb-mcp), maintained
  by the Janitor. OM and context-mode feed it; neither replaces it.
- MCP servers: `kb` (vault) + `deja` (session search) enabled in `~/.pi/agent/mcp.json`.
  github/atlassian/shopify-dev-mcp deliberately disabled (tool-restraint).
- Project trust: use `/trust` once in trusted repos. Keep `defaultProjectTrust` at `"ask"`.
- Hooks: if `pi-yaml-hooks` is installed, run `/hooks-status` to verify on first session.
- Subagentura: use `subagent_isolated` for narrow, parallelisable tasks. Default to the
  main thread for anything requiring full context.

## Token awareness

RTK has no PI mode yet. Prefer scoped reads, Grep before reading large files,
and `pi --list-models` rather than reading the raw model-list JSON.

<!-- BEGIN COMPOUND PI TOOL MAP -->
## Compound Engineering (Pi compatibility)

This block is managed by compound-plugin.

Pi extensions used by this plugin:
- Required: `@gotgenes/pi-subagents` provides the `subagent` tool used by skills that dispatch parallel agents
- Recommended: `pi-ask-user` (by edlsh) provides the `ask_user` tool; skills fall back to numbered options in chat when it is missing

Install with:
  pi install npm:@gotgenes/pi-subagents
  pi install npm:pi-ask-user
<!-- END COMPOUND PI TOOL MAP -->

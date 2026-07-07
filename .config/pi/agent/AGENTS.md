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

## Memory (kb)

CLI: `$VAULT_AI/tools/kb` (canonical); `~/dotfiles/scripts/brain` is a shim that execs `kb`; `kb` symlink also works.
Vault: `~/Vaults/AI` (macOS, git-backed) — tier map: `personal/`, `modules/`, `projects/`, `infra/`, `sessions/`, `_ops/`

At the start of each session, if context is unclear, run:
```bash
kb load
```

Slug resolution: explicit `--slug` > `$KB_SLUG` env > `personal` (when cwd is inside `$VAULT_AI`) > active plan `repo:` > `git` basename > `$PWD` basename.

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

## Skills

Shared skills live in `~/.agents/skills/`. PI discovers these automatically.
Use `/skill:<name>` to load and run a skill.

Key shared skills available: `dotfiles`, `kb`, `code-reviewer`, `problem-solver`,
`context-bridge`, `standup`, `morning-brief`, `dot-doctor`, `jira-assistant`,
`code-cleaner`, `shopify`, `pi` (PI-specific daily-driver reference).

## PI-specific

- Model selection: use spark presets via `/preset`. `fast` (Composer 2.5) for shell/edits,
  `sonnet` (Sonnet 4.6) for regular work, `think` (Sonnet 5) for planning/review.
- MCP servers: `pi-mcp-adapter` auto-loads `~/.cursor/mcp.json` servers (github, shopify-dev).
- Project trust: use `/trust` once in trusted repos. Keep `defaultProjectTrust` at `"ask"`.
- Hooks: if `pi-yaml-hooks` is installed, run `/hooks-status` to verify on first session.
- Subagentura: use `subagent_isolated` for narrow, parallelisable tasks. Default to the
  main thread for anything requiring full context.

## Token awareness

RTK has no PI mode yet. Prefer scoped reads, Grep before reading large files,
and `pi --list-models cursor` rather than reading the raw model-list JSON.

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

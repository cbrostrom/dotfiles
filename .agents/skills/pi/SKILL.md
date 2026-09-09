---
name: pi
description: "Pi daily-driver reference. Use when checking models, MCP wiring, hook health, pi-cursor-sdk, or Pi usage alongside dotfiles. Triggers: Pi model selection, scoped models, Cursor SDK, MCP setup, hooks, subagents, Pi config."
---

# PI Daily-Driver Skill

Reference for Christian's PI coding agent daily-driver setup. Shares the same
policy spine, skills, and vault as Cursor (and other agents via `.agents/`).

## Quick model reference

Scoped models (`enabledModels` / Ctrl+P / `/scoped-models`) — from `settings.base.json`:

| Model | Use for |
|-------|---------|
| `default` (cursor Auto, **default**) | Work account — included Auto pool |
| `composer-2.5` | Work account — included Composer pool |
| `github-copilot/claude-sonnet-5` | Copilot Sonnet |
| `github-copilot/claude-opus-5` | Copilot Opus |
| `github-copilot/gpt-5.6-*` | Copilot GPT 5.6 |
| `github-copilot/claude-haiku-4.5` | Cheap Copilot Claude |
| `github-copilot/gpt-5.4-mini` / `gpt-5-mini` | Cheap Copilot GPT |
| `github-copilot/gemini-3.5-flash` | Copilot Gemini |
| `opencode/big-pickle` | Free zen proxy when off work Cursor |

Non-allowlisted `cursor/*` models are omitted from `enabledModels` (guard would revert them).

Cycle: **Ctrl+P / Shift+Ctrl+P**. List: `/scoped-models`. Full registry: `/model` or `pi --list-models <provider>`.

**Not used:** spark presets, `--preset`, `/preset`, `pif`/`pit`.

**Cost control (hard rules):**

- Default driver: `default` (work account Auto). Thinking default from settings.
- Cursor via `pi-cursor-sdk` + API key (bills to Cursor plan pools).
- Only Auto / Composer are allowed on Cursor. Extension `cursor-model-guard` **reverts** any other `cursor/*` selection.
- `PI_CURSOR_RUNTIME=local`, `PI_CURSOR_SETTING_SOURCES=none`, and `PI_CURSOR_ASK_QUESTION=0` in `~/.pi/agent/configs/.env`.
- Decisions: use `ask_user` / `pi__ask_user` only — never `cursor_ask_question`.
- Set Cursor dashboard on-demand spend limit to **$0**.
- Avoid parallel subagents unless the win is clear (Explore uses Opus).

## Installed Cursor stack

```
pi-cursor-sdk          — Cursor models via @cursor/sdk (local agent loop)
cursor-model-guard     — blocks non-allowlisted cursor/* models
env-loader             — loads ~/.pi/agent/configs/.env
```

Auth: `/login` → API key → Cursor (or `CURSOR_API_KEY`). Does **not** reuse `agent` CLI OAuth.

Upgrade packages: `fnm use default && pi update --all`  
List installed: `pi list`

> Always update PI from fnm default — the `~/.local/bin/pi` shim calls the default version's binary.

## MCP

Two layers (tool-restraint):

1. **Hot path (classic):** `~/.pi/agent/mcp.json` — `higgins` + `deja` with `directTools: true`.
2. **Everything else (MCPorter):** `pi-mcporter` + `~/.pi/agent/mcporter.json` (`defaultExposure: index`).
   Discover/call via the `mcporter` tool (`search` → `describe` → `call`), or shell `mcporter call server.tool …`.
   Server defs live in `~/.mcporter/mcporter.json` (dotfiles: `.config/mcporter/mcporter.json`).

Cursor uses a curated `mcporter serve --stdio` bridge (`.cursor/mcp.json`) for a small keep-alive allowlist — not a full schema dump of dockhand.

`pi-mcp-adapter` may still discover host configs; keep non-hot servers out of Pi `mcp.json`.

Status: `/mcp status` · `/mcporter status` · `mcporter list`

## Subagent usage (@gotgenes/pi-subagents)

- Use `subagent` with `subagent_type: "Explore"` for fast read-only codebase sweeps.
- Use `run_in_background: true` for parallel info gathering; poll with `get_subagent_result`.
- Global `Explore` agent uses Claude Opus; main session stays on scoped models.
- Default to the main thread unless parallelism gives a clear win.

## Brain and memory

Run `higgins load` manually at the start of meaningful sessions, or type `.recall`.
Save: `.remember` / `.r` → `higgins digest`.
Note: `.note <text>` → `higgins current`.
Gotcha: `.gotcha <text>` → `higgins gotcha`.
Session summary: `/recap` / `/recap save` (smart-recap extension).

## Skills

PI discovers `~/.agents/skills/` automatically. Shared skills via `/skill:<name>`.

## Hooks (pi-yaml-hooks)

Global hooks: `~/.pi/agent/hook/hooks.yaml` (symlinked from dotfiles).
Validate: `/hooks-validate` · Status: `/hooks-status` · Reload: `/hooks-reload`

## Verification commands

```bash
pi list                         # Installed packages
pi --list-models cursor         # Cursor catalog
pi --version                    # PI version
/scoped-models                  # Pick from enabledModels
/hooks-validate                 # Hook config validity
```

## dotfiles integration

- `~/dotfiles/.config/pi/agent/AGENTS.md` → `~/.pi/agent/AGENTS.md`
- `~/dotfiles/.config/pi/agent/settings.base.json` → merged into `~/.pi/agent/settings.json`
- `~/dotfiles/.config/pi/agent/hook/hooks.yaml` → `~/.pi/agent/hook/hooks.yaml`
- Extensions: `cursor-model-guard/`, footer, styled-outputs, …

Local-only (never committed): `auth.json`, `trust.json`, `sessions/`, `npm/`,
`cursor-sdk.json`, `configs/.env`, `cursor-sdk-model-list.json`.

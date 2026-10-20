---
name: pi
description: "Pi setup reference: models, MCP and tool restraint, hooks, capability map. Triggers: scoped models, MCP wiring, is there a tool for X."
disable-model-invocation: true
---

# PI Daily-Driver Skill

Reference for Christian's PI coding agent daily-driver setup. Shares the same
policy spine, skills, and vault as other agents via `.agents/`.

## Quick model reference

Models in use (Ctrl+P / Shift+Ctrl+P, list via `/scoped-models` — no allowlist is seeded, so it shows every reachable model):

| Model | Use for |
|-------|---------|
| `github-copilot/*` | Private ops / misc (GPT 5.6, Gemini, Copilot-billed Claude; pick deliberately) |
| `opencode-go/*` (**default**) | Private ops and servers (`glm-5.3-flash`) |

Cycle: **Ctrl+P / Shift+Ctrl+P**. List: `/scoped-models`. Full registry: `/model` or `pi --list-models <provider>`.

**Not used:** spark presets, `--preset`, `/preset`, `pif`/`pit`.

**Rules:**

- Pi is private/ops only → `opencode-go/*` by default, `github-copilot/*` on purpose. Work repos belong in Claude Code, not Pi.
- Model restrictions are policy-by-convention: no extension enforces the allowlist any more.
- Decisions: use `ask_user` / `pi__ask_user`.
- Avoid parallel subagents unless the win is clear.

Auth: `/login` → Anthropic (Claude Pro/Max), GitHub Copilot, OpenCode Go.

## Claude in Pi

- **Harness:** `pi` → Pi-Bolt shim (`PI_BACKEND=auto`). Claude Code CLI is not required; subscription OAuth lives in `auth.json`.
- **Cache:** `PI_CACHE_RETENTION=long` in `~/.pi/agent/configs/.env` (1h Anthropic prompt cache). Keep `cacheWarming` at default `streaming`; avoid `idle` warming between runs.
- **Stable system prompt:** No per-turn `systemPrompt` mutations (`style` is session-stable; no mode-switch extensions loaded). Prose rules: `/skill:writing` (not an extension).
- **Thinking ladder:** default `low` on workstation; escalate model tier (Sonnet → Opus → Fable) before cranking thinking.
- **Background work:** observational-memory and Paseo metadata on OpenCode Go — not Claude/Copilot quota.

Upgrade packages: `piup` (`pi update --all` + `pi-doctor.sh`)  
List installed: `pi list`  
Health: `~/dotfiles/scripts/pi-doctor.sh` (`--fix` reinstall, `--prune` drop duplicate copies)

> **Stack (one config dir `~/.pi/agent`):**  
> - `pi` → shim → **Pi-Bolt** by default (`PI_BACKEND=auto`, ~30ms startup).  
> - **Managed** pi.dev pin: `pi-managed`, `~/.pi/agent/install/releases/*`; `piup` runs `pi-managed update self`.  
> - **PiG** (faster, lighter): `pipig` / `PI_BACKEND=pig` / `pi-pig` — TS extension gaps (yaml-hooks); see `~/.pi/agent/pig-migration/audit.md`.  
> - npm fallback: `pi-npm` / `PI_BACKEND=npm` at `~/.npm-global`.  
> `~/bin/pi` must stay on the shim (not managed launcher). `pi-doctor --fix` enforces that.  
> After updates: restart agents pi-doctor lists.

## MCP

Tool restraint: more tools means more ways to fail and a higher cognitive load. Enable only the servers the
current work uses, prefer official servers for credentialed tools, and add a call-logging hook before any
write-scoped server. If the agent picks the wrong tool, fix it with fewer tools and clearer descriptions,
not a smarter model. Never put mega-servers (dockhand, 300+ tools) in native Pi exposure; use MCPorter per host.

Two layers:

1. **Hot path (classic):** `~/.pi/agent/mcp.json` — `higgins` + `deja` with `directTools: true` (currently disabled entries; use MCPorter for hot path in practice).
2. **Everything else (MCPorter):** `pi-mcporter` + `~/.pi/agent/mcporter.json` (`defaultExposure: index`).
   Discover/call via the `mcporter` tool (`search` → `describe` → `call`), or shell `mcporter call server.tool …`.
   Server defs live in `~/.mcporter/mcporter.json` (dotfiles: `.config/mcporter/mcporter.json`).

`hostConfigDiscovery` is **off** in Pi `mcp.json` — do not import host MCP dumps.

`pi-mcp-adapter` may still discover host configs; keep non-hot servers out of Pi `mcp.json`.

Status: `/mcp status` · `/mcporter status` · `mcporter list`

## Subagent usage (@gotgenes/pi-subagents)

- Use `subagent` with `subagent_type: "Explore"` for fast read-only codebase sweeps.
- Use `run_in_background: true` for parallel info gathering; poll with `get_subagent_result`.
- Global `Explore` agent uses `opencode-go/glm-5.3-flash`; main session stays on scoped models.
- Default to the main thread unless parallelism gives a clear win.

## Brain and memory

Run `higgins load` manually at the start of meaningful sessions, or type `.recall`.
Save: `.remember` / `.r` → `higgins digest`.
Note: `.note <text>` → `higgins current`.
Gotcha: `.gotcha <text>` → `higgins gotcha`.
Session summary: `/recap` / `/recap save` (smart-recap extension).

## Skills

PI discovers `~/.agents/skills/` automatically. Shared skills via `/skill:<name>`.
Pi-only skills live under `~/.pi/agent/skills/` (e.g. `lfg`); avoid duplicating names already in `.agents/skills/`.

## Capability map

For "is there a tool for X": read `~/.agents/capabilities.md` (generated by `~/dotfiles/scripts/gen-capabilities.py`,
never edit by hand). Check the verify paths in its header exist; if any is missing, rerun the generator and re-read.
Route with one to three entries: `name, why, where it lives, how to invoke`. If nothing matches, say so.

## Hooks (pi-yaml-hooks)

Global hooks: `~/.pi/agent/hook/hooks.yaml` (symlinked from dotfiles).
Validate: `/hooks-validate` · Status: `/hooks-status` · Reload: `/hooks-reload`

## Verification commands

```bash
pi list                         # Installed packages
pi --list-models github-copilot # Copilot catalog
pi --version                    # PI version
/scoped-models                  # Pick from enabledModels
/hooks-validate                 # Hook config validity
```

## dotfiles integration

- `~/dotfiles/stow/pi/.pi/agent/AGENTS.md` → `~/.pi/agent/AGENTS.md`
- `~/dotfiles/setup/pi/settings.base.json` → merged into `~/.pi/agent/settings.json`
- `~/dotfiles/stow/pi/.pi/agent/hook/hooks.yaml` → `~/.pi/agent/hook/hooks.yaml`
- Extensions: footer, styled-outputs, …

Local-only (never committed): `auth.json`, `trust.json`, `sessions/`, `npm/`, `configs/.env`.

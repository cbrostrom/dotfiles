---
name: dotfiles
description: "Architecture and implementation knowledge for ~/dotfiles. Use when tracing config paths, settings layers, hook flows, skill routing, module install, or Higgins vault integration. Also use before editing hooks, install scripts, skills, or symlinks — outlines plan with complexity estimate before any edit. Triggers: how does X work, dotfiles setup, config path, hook flow."
---

# Dotfiles Skill

Reference for Christian's dotfiles at `~/dotfiles`. Covers architecture understanding and safe implementation.

## Architecture

### Settings Layers (Pi)
```
.settings.base.json (in .config/pi/agent/)
  → platform overlays where present
  → local/runtime fields patched by install (not fully symlinked)
```
Cursor settings live under `.config/cursor/` and `~/.cursor/` via install scripts.

### Hooks

**Cursor** — `~/.cursor/hooks.json` (managed by `scripts/cursor/install-cursor-config.sh`):
- `sessionStart`: MCP-only (no vault dump); agent uses Higgins search on demand
- `preToolUse[Shell]`: `rtk hook cursor` via `run-hook.sh`
- `afterFileEdit`: `aislop hook cursor` via `run-hook.sh`
- Timeouts are **seconds** in Cursor; never use ms values there.

**Pi** — hooks via `~/.pi/agent/hook/hooks.yaml` (pi-yaml-hooks) and Pi extensions.

### Skills
| Layer | Path | Visible to |
|---|---|---|
| Shared agnostic | `.agents/skills/` → `~/.agents/skills/` | All agents |
| Cursor | `~/.cursor/skills` → `~/.agents/skills` (symlink) | Cursor |
| Pi extras | `~/.pi/agent/skills/` (CE compound, moli, etc.) | Pi |
| Cursor built-ins | `~/.cursor/skills-cursor/` | Cursor (do not touch) |

Promotion rule: cross-agent workflows go in `.agents/skills/<name>/SKILL.md`.

### Subagents
`.cursor/agents/*.md` — user-level, all Cursor projects.

### Modules
- `modules/<name>/module.sh`, `install.sh`, optional `uninstall.sh`
- Controlled by `modules.conf` (opt-in per machine)
- Key modules: `pi`, `herdr`, `mcp-servers`, `skills`, `symlinks`, `fonts`, `packages`, `zsh`

### Memory (Higgins)
- CLI: `higgins` (`~/.local/bin/higgins`)
- Vault: `~/Vaults/Higgins/AI` — tiers: `personal/`, `modules/`, `projects/`, `infra/`, `sessions/`, `_ops/`
- Never auto-load at session start. Prefer `search` with specific terms; `load` only when asked.

### RTK (Token Compression)
- Rewrite policy: `scripts/rtk/rewrite-command.sh`
- Cursor: auto via `rtk hook cursor`; others: `rtk <cmd>` or Pi RTK optimizer

### Propagation
- `dotfiles --update` — local only
- `/dotfiles` skill — local + propagate to LinuxBro + SuperBro via SSH

## Implementation Rules

**Before any edit:**
1. State files touched, change intent, break risk, verification.
2. Ask for permission. Never proceed without explicit approval.

**What can be changed:**
- Modules, symlinks, zsh, Brewfile
- Skills: `.agents/skills/`
- Cursor: `.cursor/`, `scripts/cursor/`
- Pi: `.config/pi/`, `modules/pi/`
- Agent policy: `AGENTS.md`, `.cursor/rules/core.mdc`

**What must not be changed casually:**
- Generated/local override files
- `~/.cursor/skills-cursor/` (Cursor-managed)
- Push to remote without whitelist approval

**After every change:**
1. `bash -n <script>` for shell; `python3 -m json.tool <file>` for JSON
2. `./bootstrap.sh --list` if modules touched
3. `scripts/cursor/install-cursor-config.sh` if Cursor hooks touched
4. Report what was done and what to verify manually

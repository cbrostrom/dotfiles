---
name: dotfiles
description: Dotfiles architecture and implementation knowledge for Christian's dotfiles repo at ~/dotfiles. Use when asking how the dotfiles setup works, tracing config paths, understanding settings layers, hook flows, skill routing, module install, device snapshots, or brain integration. Also use when making approved changes to dotfiles — hooks, settings layers, modules, install scripts, skills config, symlinks. Always present a plan with complexity estimate and ask for permission before any edit.
---

# Dotfiles Skill

Reference for Christian's dotfiles at `~/dotfiles`. Covers architecture understanding and safe implementation.

## Architecture

### Settings Layers
```
settings.base.json
  → settings.{darwin,linux,wsl}.json
  → settings.override.json (gitignored, per-machine)
  → settings.local.json   (generated on SessionStart — NEVER edit directly)
```
- Merge rules: `_merge-config.json` (replace-by-command, replace-by-matcher+command strategies per key)
- Doctor/repair: `./modules/claude-settings/doctor.sh --fix`

### Hooks
**Claude Code** — `.claude/hooks/`:
- `effort-classifier.sh` UserPromptSubmit → tier hint
- `brain-save-inject.sh` PreCompact + UserPromptSubmit → vault save
- `brain-load.sh` SessionStart → vault context injection
- `git-push-guard.sh` PreToolUse[Bash] → whitelist guard
- `rtk-rewrite.sh` PreToolUse[Bash] → token compression via RTK
- `fast-mode-guard.sh` UserPromptSubmit → Opus cost warning
- `statusline.sh` → statusLine command

**Cursor** — `~/.cursor/hooks.json` (managed by `scripts/cursor/install-cursor-config.sh`):
- `sessionStart`: brain-load via `run-hook.sh`
- `preToolUse[Shell]`: `rtk hook cursor` via `run-hook.sh`
- `afterFileEdit`: `aislop hook cursor` via `run-hook.sh`
- `run-hook.sh` wraps all hooks; logs failures/slow runs to `~/.local/state/cursor-hooks/hooks.log`
- Timeouts are **seconds** in Cursor; never use ms values there.

### Skills
| Layer | Path | Visible to |
|---|---|---|
| Shared agnostic | `.agents/skills/` → `~/.agents/skills/` | All agents |
| Cursor | `~/.cursor/skills` → `~/.agents/skills` (symlink) | Cursor |
| Claude-only | `.claude/skills/` | Claude Code only |
| Codex-only | `.codex/skills/` | Codex only |
| Cursor built-ins | `~/.cursor/skills-cursor/` | Cursor (do not touch) |

Promotion rule: when a workflow should work in any agent, write it in `.agents/skills/<name>/SKILL.md`. Keep tool glue in adapters.

### Subagents
`.cursor/agents/*.md` — user-level, all Cursor projects.
Wrappers reference `.agents/skills/` for reusable logic; Cursor-specific routing/model/context-isolation in the agent file itself.

### Modules
- `modules/<name>/module.sh`, `install.sh`, optional `uninstall.sh`
- Controlled by `modules.conf` (opt-in per machine)
- Key modules: `claude-settings`, `mcp-servers`, `skills`, `symlinks`, `fonts`, `herdr`, `engram`

### Brain (Memory)
- CLI: `~/.local/bin/brain` → `~/dotfiles/scripts/brain` (Python, no deps)
- Vault: `~/Vaults/Brain/Brains/<slug>/` — `current.md`, `next.md`, `gotchas.md`, `history/`
- SessionStart hook loads vault context automatically in both Claude Code and Cursor

### Devices
- `.claude/devices/` — per-host snapshots auto-updated by pre-commit hook
- Canonical names: lowercase hostname (`linuxbro.json`, `superbro.json`, `GY-M-WHKK2PF6N7.json`)

### RTK (Token Compression)
- Rewrite policy: `scripts/rtk/rewrite-command.sh`
- Covers: git, gh, cargo, npm, pnpm, docker, kubectl, pytest, vitest, eslint, ruff, go, curl, ls, grep, etc.
- Claude Code: auto via `rtk hook claude`; Cursor: auto via `rtk hook cursor`; Others: use `rtk <cmd>` manually

### Push Guard
- `~/.claude/push-whitelist.txt` — repos allowed to push
- Client repos (`~/Projects/Clients`, `~/Projects/Shopify`, `~/Work`) never whitelisted

### Propagation
- `dotfiles --update` — local only
- `/dotfiles` skill — local + propagate to LinuxBro + SuperBro via SSH

## Implementation Rules

**Before any edit:**
1. State what files will be touched, what the change does, what could break, and verification steps.
2. Estimate complexity and recommend a model:

| Complexity | Criteria | Model |
|---|---|---|
| Trivial | 1-2 files, mechanical | `composer-2.5-fast` |
| Medium | 2-4 files, logic changes | `claude-4.6-sonnet-medium-thinking` |
| Complex | 5+ files, cross-cutting | `claude-4.6-opus-high-thinking` — recommend splitting |

3. Ask for permission. Never proceed without explicit approval.

**What can be changed:**
- Settings layers: `settings.base.json`, `settings.{darwin,linux,wsl}.json`, `_merge-config.json`
- Hooks: `.claude/hooks/`, `.cursor/hooks/`, `scripts/cursor/install-cursor-config.sh`
- Skills: `.agents/skills/`, `.claude/skills/`, skill promotion
- Modules: `modules/*/install.sh`, module creation
- Install scripts: `scripts/install/symlinks.sh`, `scripts/cursor/`, `scripts/claude/`
- Agent config: `AGENTS.md`, `.cursor/rules/core.mdc`, `.cursor/agents/`, `.claude/CLAUDE.md`
- Brain: `scripts/brain`

**What must not be changed:**
- `settings.local.json` (generated, wiped on SessionStart)
- `settings.override.json` (local gitignored overrides)
- `~/.cursor/skills-cursor/` (Cursor-managed)
- Push to remote without whitelist approval

**After every change:**
1. `bash -n <script>` for shell; `python3 -m json.tool <file>` for JSON
2. `./modules/claude-settings/doctor.sh --fix` if settings layers touched
3. `scripts/cursor/install-cursor-config.sh` if Cursor hooks touched
4. Report what was done and what to verify manually

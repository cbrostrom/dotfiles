---
name: pi
description: PI coding agent daily-driver reference. Use when working inside PI, checking preset/recap/model choices, wiring MCP or subagentura, verifying hook health, or when asked how to use PI alongside the agnostic dotfiles setup. Also use when another agent needs to explain PI usage to the user.
---

# PI Daily-Driver Skill

Reference for Christian's PI coding agent daily-driver setup. PI runs Cursor models
through `pi-cursor-sdk` and shares the same policy spine, skills, brain, and MCP
servers as Cursor and Claude Code.

## Quick model reference

| Preset | Model | Thinking | Use for |
|--------|-------|----------|---------|
| `fast` | Cursor Composer 2.5 | off | Quick edits, shell, chat |
| `sonnet` | Cursor Sonnet 4.6 (200k) | medium | Default work |
| `think` | Cursor Sonnet 5 | high | Planning, specs, deep review |
| — (recap) | Cursor Haiku 4.5 | off | Idle/on-demand recap |

Switch preset: `/preset fast`, `/preset sonnet`, `/preset think`
Or start PI on a preset: `pi --preset sonnet`
Show all models: `pi --list-models cursor`
Refresh live catalog: `/cursor-refresh-models`

## Installed extensions

```
pi-cursor-sdk      0.1.53  — Cursor models via local SDK agent runtime
pi-mcp-adapter     2.10.0  — Lazy MCP proxy (auto-picks up ~/.cursor/mcp.json)
pi-spark           0.15.0  — Presets, recap, compact TUI
pi-stats-ext       0.1.0   — Token/cost dashboard (/pi-stats)
@gotgenes/pi-subagents  — In-process subagents (subagent, get_subagent_result, steer_subagent)
```

Upgrade all: `fnm use default && pi update --all`
List installed: `pi list`

> Always update PI from fnm default — the `~/.local/bin/pi` shim calls the default version's binary.
> Updating from a project-local node version installs the new PI there instead, creating a stale shim.

## MCP adapter

`pi-mcp-adapter` auto-reads `~/.cursor/mcp.json`. Your github and shopify-dev-mcp
servers are available in PI with no extra config. One proxied `mcp` tool instead of
the full tool blast.

## Subagent usage (@gotgenes/pi-subagents)

- Use `subagent` with `subagent_type: "Explore"` for fast read-only codebase sweeps.
- Use `run_in_background: true` for parallel info gathering; poll with `get_subagent_result`.
- Global `Explore` agent uses Composer 2.5; main session stays on Sonnet 4.6.
- Default to the main thread unless parallelism gives a clear win.

## Brain and memory

PI does not auto-load the brain the way Claude Code does via SessionStart hook.
Run `brain load` manually at the start of meaningful sessions, or type `.recall`.

Save context: `.remember` / `.r` triggers the context-bridge skill.
Single note: `.note <text>` → `brain current "<text>"`.
Gotcha: `.gotcha <text>` → `brain gotcha "<text>"`.

## Skills

PI discovers `~/.agents/skills/` automatically. All shared dotfiles skills are
available via `/skill:<name>` inside PI. The `/skill:` autocomplete lists them.

## Hooks (pi-yaml-hooks)

Global hooks live in `~/.pi/agent/hook/hooks.yaml` (symlinked from dotfiles).

Install: `pi install npm:pi-yaml-hooks`
Validate: `/hooks-validate`
Status: `/hooks-status`
Reload: `/hooks-reload`
Disable a hook: comment it out in `~/dotfiles/.config/pi/agent/hook/hooks.yaml`
then `/hooks-reload` inside PI.

Hook behaviour (after install + validate):
- `session.created` → readiness notification
- `session.idle` → brain-save nudge
- `file.changed` (code files) → `aislop hook pi` score check
- `tool.before.bash` → blocks force-push / rm-rf root / publish commands (exit 2)

**Limitation vs Cursor:** PI hooks cannot inject text into model context (`additional_context`
is Cursor-specific). PI hooks can guard, observe, notify, and prompt, not rewrite.

## Project setup (per-project overlay)

1. `cd <project>` and start PI.
2. Trust the project: `/trust` (written to `~/.pi/agent/trust.json`).
3. Add `.pi/settings.json` for project-specific packages/model overrides.
4. Add `.pi/hook/hooks.yaml` for project-specific hooks (trusted, loaded on top of global).
5. Project `.agents/skills/` is auto-discovered after trust.
6. Project `AGENTS.md` or `CLAUDE.md` loads as context regardless of trust.

## Verification commands

```bash
pi list                         # Installed extensions
pi --list-models cursor         # Live model catalog
pi --version                    # PI version
/preset                         # Show/select Spark presets
/recap                          # Manual recap
/pi-stats                       # Token/cost dashboard
/hooks-validate                 # Hook config validity (requires pi-yaml-hooks)
/hooks-status                   # Trust state + active hooks
```

## dotfiles integration

Config sources (git-tracked in ~/dotfiles):
- `~/dotfiles/.config/pi/agent/AGENTS.md` → `~/.pi/agent/AGENTS.md`
- `~/dotfiles/.config/pi/agent/spark.json` → `~/.pi/agent/spark.json`
- `~/dotfiles/.config/pi/agent/hook/hooks.yaml` → `~/.pi/agent/hook/hooks.yaml`
- `~/dotfiles/.config/pi/agent/settings.base.json` → merged into `~/.pi/agent/settings.json`

To re-apply after changing dotfiles: `dotfiles --update` (if `pi` module is enabled)
or `bash ~/dotfiles/modules/pi/install.sh`.

Local-only (never committed): `auth.json`, `cursor-sdk-model-list.json`,
`cursor-sdk.json`, `trust.json`, `sessions/`, `npm/`, `pi-stats/`.

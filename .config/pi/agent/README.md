# PI Configuration — Christian's daily-driver setup

Part of the [dotfiles](https://github.com/bybrostrom/dotfiles) monorepo.
Installed via `modules/pi/install.sh` — opt-in per machine.

## Principles

- **Layers, not silos.** Each component handles one concern.
- **Zero-token automation.** No LLM calls for routine maintenance.
- **Deterministic.** Same input → same output. No surprises.
- **Vault-backed.** Knowledge lives in markdown, synced via Syncthing.
- **Easy install.** Clone dotfiles → run `install.sh` → done.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                       PI Coding Agent                        │
├─────────────────────────────────────────────────────────────┤
│  Extensions (symlinked from dotfiles)                        │
│  ├─ rtk.ts             — RTK optimizer integration           │
│  ├─ footer/            — 2-row status bar                    │
│  ├─ styled-outputs/    — full TUI visual design              │
│  ├─ chat-mode/         — /chat read-only toggle              │
│  ├─ plan-mode/         — /plan tool-locked planning          │
│  ├─ chat-input/        — styled input border                 │
│  ├─ startup/           — session welcome header              │
│  ├─ env-loader/        — .env injection at startup           │
│  ├─ cursor-model-guard — Cursor allowlist (Auto/Composer)    │
│  └─ protected-paths/   — AI-safe path deny list              │
├─────────────────────────────────────────────────────────────┤
│  Packages (settings.base.json → packages)                    │
│  ├─ pi-cursor-sdk / pi-rtk-optimizer / context-mode          │
│  ├─ pi-yaml-hooks / pi-ask-user / pi-mcp-adapter             │
│  ├─ pi-extensions (neanderthal, smart-recap, …)              │
│  └─ see Installed Packages below                             │
├─────────────────────────────────────────────────────────────┤
│  Hooks (symlinked)                                            │
│  ├─ idle-kb-tidy       — silent prune + compact              │
│  ├─ aislop-after-edit  — code quality check                  │
│  └─ guard-destructive  — block force-push, publish           │
├─────────────────────────────────────────────────────────────┤
│  Prompt templates (/commands)                                 │
│  ├─ /end              — EOD vault save + re-index            │
│  ├─ /organise         — triage inbox                         │
│  └─ /handover         — extract sessions to vault (handoff)  │
└─────────────────────────────────────────────────────────────┘
```

## Memory Pipeline

| Layer | What | When | Token cost |
|---|---|---|---|
| **pi-rtk-optimizer** | Compacts tool outputs, filters source noise | Every tool result | Zero |
| **context-mode** | Session/event memory + indexed docs (not vault) | Every search | Zero |
| **handover** | Sessions → structured vault markdown (handoff artifact) | EOD (`/handover`) | Zero |

Durable brain: Higgins vault (`higgins` CLI + MCP). context-mode and `/handover` feed it; neither replaces it.

## Model selection

Scoped models live in `settings.base.json` → `enabledModels`.
Cycle with Ctrl+P / Shift+Ctrl+P. List with `/scoped-models`.
Full registry: `/model` or `pi --list-models <provider>`.
Default: `default` (cursor Auto). Guard: `cursor-model-guard` extension.

## Installed Packages

Aligned with `settings.base.json` → `packages` (plus a few local installs not yet in that array).

### In settings.base.json

| Package | Purpose |
|---|---|
| `pi-extension-settings` | UI for extension configuration |
| `pi-cursor-sdk` | Cursor models via `@cursor/sdk` |
| `pi-yaml-hooks` | Hook system for PI lifecycle events |
| `pi-ask-user` | Interactive user prompts |
| `pi-web-access` | Web fetch and search |
| `pi-caffeinate` | Keep terminal awake during long runs |
| `pi-subagents` | Parallel subagent execution |
| `context-mode` | FTS5 session/event memory + indexed docs |
| `pi-mcp-adapter` | Classic MCP gateway (higgins, deja hot path) |
| `pi-mcporter` | MCP-as-tool-calls (`search`/`describe`/`call`, index exposure) |
| `pi-rtk-optimizer` | Output compaction, source filtering |
| `bybrostrom/pi-extensions` | neanderthal, smart-recap, pane-notify, escape-guard, … |
| `pi-peer` | Cross-session messaging |
| `rpiv-todo` | Todo tool |

### Also installed locally (`pi list`) — not in settings.base.json yet

| Package | Purpose |
|---|---|
| `pi-permission-system` | Permission policy |
| `pi-extmgr` | Extension manager |
| `pi-cmux` | cmux workspace helpers |

### Not installed (do not re-add casually)

`pi-spark`, `pi-caveman` (replaced by neanderthal), `@thisux/pi-double-esc-clear`,
`pi-powerbar`, `pi-ralph-wiggum`, `pi-intercom`, and other stale README entries.

## Hooks

| Hook | Event | What it does |
|---|---|---|
| `idle-kb-tidy` | session.idle | Silently prunes + compacts brain files |
| `aislop-after-edit` | file.changed | AI slop quality check on code edits |
| `guard-destructive` | tool.before.bash | Blocks force-push, publish commands |

## Files

```
dotfiles/.config/pi/agent/
├── AGENTS.md                  # Global policy adapter
├── README.md                  # This file
├── extensions/                # Homegrown extensions
├── hook/
│   └── hooks.yaml             # Global hooks config
├── prompts/                   # Slash commands
│   ├── end.md
│   ├── organise.md
│   └── handover.md
├── settings.base.json         # Merged into settings.json (enabledModels + packages)
├── mcp.json                   # Classic MCP: higgins + deja
├── mcporter.json              # pi-mcporter exposure (index default)
└── scripts/
```

Canonical MCPorter server defs: `dotfiles/.config/mcporter/mcporter.json` → `~/.mcporter/mcporter.json`.
Cursor bridge: `dotfiles/.cursor/mcp.json` → `mcporter serve --stdio` (curated keep-alive allowlist).

## Fresh Install

```bash
git clone git@github.com:bybrostrom/dotfiles.git ~/dotfiles
echo "pi" >> ~/.config/dotfiles/modules.conf
~/dotfiles/modules/pi/install.sh
# Packages install from settings.base.json on next pi start / pi update
/reload
```

## Related

- **Vault:** `higgins` CLI at `~/.local/bin/higgins`
- **Brain files:** `~/Vaults/Higgins/AI/personal/{current,gotchas,next}.md`
- **Skill:** `.agents/skills/pi/SKILL.md`

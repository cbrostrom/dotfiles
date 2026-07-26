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
│  ├─ working-state.ts   — deterministic compaction            │
│  ├─ kb-project.ts      — project-aware kb context            │
│  ├─ rtk.ts             — RTK optimizer integration           │
│  ├─ whimsical.ts       — quality-of-life helpers             │
│  └─ working-indicator.ts — session activity indicator        │
├─────────────────────────────────────────────────────────────┤
│  Extensions (npm packages)                                   │
│  ├─ pi-rtk-optimizer   — output compaction, source filtering │
│  ├─ context-mode       — FTS5 knowledge base                 │
│  ├─ pi-tool-display    — compact tool pills                  │
│  ├─ pi-caffeinate      — keep terminal alive                 │
│  ├─ pi-spark           — model presets                       │
│  └─ 20 more (see packages list)                              │
├─────────────────────────────────────────────────────────────┤
│  Hooks (symlinked)                                            │
│  ├─ session-ready      — startup notification                │
│  ├─ vault-ctx-index    — index vault into FTS5 on start     │
│  ├─ idle-kb-tidy       — silent prune + compact              │
│  ├─ aislop-after-edit  — code quality check                  │
│  ├─ guard-destructive  — block force-push, publish           │
│  └─ kb-write-reindex   — re-index FTS5 after kb writes      │
├─────────────────────────────────────────────────────────────┤
│  Prompt templates (/commands)                                 │
│  ├─ /end              — EOD vault save + re-index            │
│  ├─ /organise         — triage inbox                         │
│  └─ /session-extract  — extract sessions to vault            │
├─────────────────────────────────────────────────────────────┤
│  Tools (quick job runner scripts)                             │
│  └─ extract.ts        — session JSONL → vault markdown       │
│                         (run via /session-extract)            │
└─────────────────────────────────────────────────────────────┘
```

## Memory Pipeline

Four layers, no overlap:

| Layer | What | When | Token cost |
|---|---|---|---|
| **pi-rtk-optimizer** | Compacts tool outputs, filters source noise | Every tool result | Zero |
| **working-state** | Strips thinking, preserves goal/decisions/files/errors | Every compaction | Zero |
| **context-mode** | FTS5 index → search instead of raw load | Every file read | Zero |
| **session-extract** | Sessions → structured vault markdown | EOD (`/session-extract`) | Zero |

## Installed Packages

### Core (essential)

| Package | Purpose |
|---|---|
| `pi-rtk-optimizer` | Read compaction, output compaction, source filtering |
| `context-mode` | FTS5 knowledge base — search indexed vault content |
| `pi-yaml-hooks` | Hook system for PI lifecycle events |
| `pi-spark` | Model presets (`fast`, `sonnet`, `think`) |
| `pi-subagents` | Parallel subagent execution |
| `pi-mcp-adapter` | MCP server gateway (kb, deja) |
| `pi-ask-user` | Interactive user prompts in extensions |

### Workflow (important)

| Package | Purpose |
|---|---|
| `pi-powerbar` | Enhanced status bar |
| `pi-tool-display` | Compact tool pills in TUI |
| `pi-interactive-shell` | Delegation to other coding agents |
| `pi-ralph-wiggum` | Long-running iterative development loops |
| `pi-intercom` | Cross-session coordination |
| `pi-chrome-devtools` | Browser inspection and control |
| `pi-raw-paste` | Raw paste mode for code blocks |
| `pi-caffeinate` | Keep terminal awake during long runs |
| `@thisux/pi-double-esc-clear` | Double-esc clears editor draft |
| `@diegopetrucci/pi-notify` | Desktop notifications on completion |
| `pi-autoresearch` | Automated optimization experiment loops |
| `pi-caveman` | Ultra-compressed communication mode |

### Quality of life (optional)

| Package | Purpose |
|---|---|
| `pi-stats-ext` | `/stats` for diagnostics |
| `pi-curated-themes` | Theme collection (using gruvbox-dark-hard) |
| `pi-web-access` | Web fetch and search for the agent |
| `pi-prompt-template-model` | Custom `/commands` (end, organise, session-extract) |
| `pi-extension-settings` | UI for extension configuration |
| `tomsej/pi-ext` | Leader-key, tool-pills, permissions |

## Model Presets (spark.json)

| Preset | Model | Thinking | Use case |
|---|---|---|---|
| `fast` | deepseek-v4-flash:cloud | off | Quick tasks, file traversal, lookups |
| `sonnet` | gemma4:31b-cloud | medium | Regular work |
| `think` | deepseek-v4-pro:cloud | high | Planning, architecture, code review |

Default model: `deepseek-v4-flash-free` (OpenCode)
Recap: `gemma4:31b-cloud` (auto-summary every 5m idle)

## Hooks

| Hook | Event | What it does |
|---|---|---|
| `session-ready` | session.created | Notifies PI is ready with vault search |
| `vault-ctx-index` | session.created | Indexes personal/ + modules/ into FTS5 |
| `idle-kb-tidy` | session.idle | Silently prunes + compacts brain files |
| `aislop-after-edit` | file.changed | AI slop quality check on code edits |
| `guard-destructive` | tool.before.bash | Blocks force-push, publish commands |
| `kb-write-reindex` | tool.after.bash | Re-indexes FTS5 after kb write operations |

## Files

All user-authored files live in `dotfiles/.config/pi/agent/` and are symlinked by `install.sh`:

```
dotfiles/.config/pi/agent/
├── AGENTS.md                  # Global policy adapter
├── README.md                  # This file
├── extensions/                # Homegrown extensions
│   ├── working-state.ts       # Deterministic compaction
│   ├── kb-project.ts          # Project-aware kb
│   ├── rtk.ts                 # RTK integration glue
│   ├── whimsical.ts           # QoL helpers
│   └── working-indicator.ts   # Activity indicator
├── hook/
│   └── hooks.yaml             # Global hooks config
├── prompts/                   # Slash commands
│   ├── end.md                 # EOD vault save
│   ├── organise.md            # Inbox triage
│   └── session-extract.md     # Session extraction
├── settings.base.json         # Merged into settings.json
├── spark.json                 # Model presets + recap
└── extensions/
    ├── extract.ts             # Session extraction script
    └── ...                    # Other extensions
```

## Fresh Install

```bash
# 1. Clone dotfiles
git clone git@github.com:bybrostrom/dotfiles.git ~/dotfiles

# 2. Enable the pi module
echo "pi" >> ~/.config/dotfiles/modules.conf

# 3. Run install
~/dotfiles/modules/pi/install.sh

# 4. Install npm packages
pi install npm:pi-rtk-optimizer
pi install npm:context-mode
pi install npm:pi-yaml-hooks
pi install npm:pi-tool-display
pi install npm:@thisux/pi-double-esc-clear
pi install npm:@diegopetrucci/pi-notify
# ... see package list above for full set

# 5. Reload PI
/reload
```

## Key Configurations

### RTK Optimizer

See `extensions/pi-rtk-optimizer/config.json` after first install.
Relevant settings:
- `outputCompaction.readCompaction.enabled: true`
- `outputCompaction.sourceCodeFiltering: "minimal"`
- `outputCompaction.smartTruncate.enabled: true`

### Working State Extension

No config needed. Hooks `session_before_compact` automatically.
Strips thinking blocks, extracts goal/decisions/files/errors/next.
Zero token cost — pure regex.

### Session Extraction

Run `/session-extract` EOD. Extracts all unprocessed sessions.
Output: `~/Vaults/Higgins/AI/sessions/YYYY/MM/<project>-<sessionId>.md`
Includes auto-learning: learned patterns written to `personal/gotchas.md` and `personal/current.md`.

## Related

- **Session extraction skill:** `dotfiles/.agents/skills/session-extract/`
- **Knowledgebase protocol:** `kb` CLI at `~/Vaults/Higgins/AI/tools/kb`
- **Brain files:** `~/Vaults/Higgins/AI/personal/{current,gotchas,next}.md`

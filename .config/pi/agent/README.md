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
| `pi-ask-user` | Interactive user prompts (schema patch: accepts `options[].label` alias) |
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
| `guard-context-mode` | tool.before.bash | Redirects raw bash (cat/curl/grep -r/...) to ctx_* tools |

## context-mode enforcement (Cursor + native)

Context-mode's own routing only catches raw bash on the built-in `bash` tool.
Cursor models bypass that entirely: `pi-cursor-sdk` runs Cursor's native agent
loop (`@cursor/sdk`), whose native tools (webSearch, webFetch, shell, read)
never fire a Pi `tool_call` event. A sampled Paseo Cursor session hit 509KB in
18 JSONL records using native webSearch/webFetch with zero bridged `ctx_*`
calls — instructions alone cannot fix this, only removing the escape hatch.

Two pieces close the gap:

1. **`extensions/context-mode-enforcer`** — a global `tool_call` guard
   (broader than the YAML hook) that blocks raw bash patterns which flood
   context (cat/curl/wget/grep -r/test runners/git diff/docker logs/...) and
   redirects to `ctx_execute` / `ctx_execute_file` / `ctx_batch_execute`.
   Also truncates oversized non-`ctx_*` tool results as a safety net.
   Fail-open if `ctx_execute` isn't active in the session (won't brick a
   session where context-mode failed to load). Escape hatch:
   `PI_CONTEXT_ENFORCER_DISABLE=1`.
2. **`patches/apply-pi-cursor-sdk-strict-mcp-patch.sh`** — patches the
   installed `pi-cursor-sdk` dist to pass `tools: ["mcp", "askQuestion"]` to
   every Cursor `Agent.create`/`Agent.resume` call. This removes Cursor's
   native tools entirely; Cursor must call back through pi-cursor-sdk's local
   MCP bridge for everything, which fires normal Pi `tool_call` events that
   `context-mode-enforcer` can see and gate. Requires
   `PI_CURSOR_EXPOSE_BUILTIN_TOOLS=1` (set in `configs/.env`) so Cursor still
   has a working `read`/`bash`/`write`/`edit` via the bridge post-restriction.
   Escape hatch: `PI_CURSOR_STRICT_MCP_ONLY=0` (restores native Cursor tools
   without reverting the patch — useful if a `pi-cursor-sdk` update needs the
   patch reapplied first). Re-run `modules/pi/install.sh` after `pi update`
   to reapply, same as the `pi-ask-user` label patch.

Verify: `/cursor-tools` in a Cursor session should show the Pi bridge with
`pi__read`/`pi__bash`/`pi__ctx_*` names and no native Cursor webSearch/shell
activity in the resulting session JSONL.

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
├── patches/
│   └── apply-pi-ask-user-label-patch.sh  # Re-run via modules/pi/install.sh after pi update
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

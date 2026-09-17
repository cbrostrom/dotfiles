# Codebase map — pi extensions

Read this before searching. Jump directly to the right file.

## Root

Runtime `~/.pi/agent/extensions/` mixes Stow-managed extensions with machine-local packages. Source of truth for managed entries is `~/dotfiles/stow/pi/.pi/agent/extensions/`.

| File | Purpose |
|------|---------|
| `CODEBASE.md` | This map |

## Key directories (dotfiles-owned)

| Entry | Purpose |
|-------|---------|
| `chat-input/` | Custom TUI input editor with companion animation |
| `chat-mode/` | `/chat` toggle: read-only conversational mode (mutually exclusive with plan mode) |
| `context-mode-enforcer/` | tool_call guard forcing large output through ctx_* tools |
| `env-loader/` | Injects `~/.pi/agent/configs/.env` into process.env at startup |
| `file-search/` | First-class `fd` and `rg` tools for pi |
| `footer/` | Status footer bar: git, model, tokens, powerbar segments |
| `llmtrim-guard/` | LLM trim guard |
| `model-policy-guard/` | Model policy enforcement |
| `plan-mode/` | `/plan` toggle: read-only plan mode with plan_complete signal |
| `protected-paths/` | Path protection guards |
| `secret-redaction/` | Last-line secret redaction defence |
| `rtk.ts` | Rewrites bash commands to `rtk` for token savings |
| `startup/` | Startup keybinding/config handling |
| `styled-outputs/` | Themed TUI renderers; built-in tool overrides (replaces `npm:pi-tool-display`) |

## Machine-local (not in dotfiles)

`orca-*.ts` (orca-managed), `pi-desktop-*.ts`, `cmux-workspaces.ts`, `pi-rtk-optimizer/`+`pi-smart-voice-notify/` (config-only dirs for npm extensions). Purposes for all entries: generated manifest at `~/.agents/capabilities.md`.

## Conventions

- Every extension `index.ts` starts with a one-line `/** purpose */` doc comment — the capability manifest extracts it; keep it accurate.
- Changes here require `/reload` in Pi; links are managed by the `pi` Stow package.

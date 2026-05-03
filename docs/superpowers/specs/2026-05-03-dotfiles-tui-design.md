# Dotfiles TUI — Design Spec
**Date:** 2026-05-03  
**Status:** Approved

## Summary

Replace the existing `dotfiles.sh` fzf-menu with a gum-based TUI. Same command (`dotfiles`), better UI. Status always visible next to actions. Tools organized in categorized submenus.

## Stack

- **Shell + gum** (Charmbracelet) — no new language, no separate binary, no releases pipeline
- gum replaces fzf for menus, adds spinners, confirmations, styled output
- fzf retained for its existing zsh use (history, file search) — not used in TUI

## File Structure

```
dotfiles/
├── dotfiles.sh           ← entry point, rewritten as gum TUI
└── tui/
    ├── status.sh         ← status checks and display
    ├── install.sh        ← guided wizard for fresh machine
    ├── update.sh         ← git pull + scripts with spinners
    └── tools/
        ├── zed.sh        ← merge settings, diff base, promote to base
        ├── symlinks.sh   ← re-link all, force update, check
        ├── fonts.sh      ← nerd fonts install
        └── secrets.sh    ← check, permissions, show defined keys
```

## Main Screen (Layout B)

Two-panel layout: status always visible on left, actions on right.

```
┌─ dotfiles ──────────────────────────────────────────┐
│  STATUS                    ACTIONS                  │
│  ✓ zsh        linked       › Install / Setup        │
│  ✓ zed        synced         Update                 │
│  ✗ secrets    missing        Tools ▶                │
│  ✓ node       v20.19.2                              │
│  ✓ cli tools  5/5           ↑↓ move  enter  q quit  │
│  last update: 2 days ago                            │
└─────────────────────────────────────────────────────┘
```

Status panel is populated by `tui/status.sh` — same checks as `doctor.sh` but formatted for gum.

## Screens

### Install / Setup (fresh machine wizard)

1. Detect OS + profile (WSL / macOS / Linux)
2. `gum choose --no-limit` — user picks what to install:
   - Packages (brew / apt)
   - Symlinks
   - Fonts
   - Zed config
   - macOS defaults (only shown on macOS)
3. `gum confirm` — "Run selected steps?"
4. Each step runs with `gum spin --title "Installing…"` wrapper
5. Summary on completion, return to main menu

### Update

Sequential steps with `gum spin` per step:
1. `git pull --rebase --autostash`
2. Re-run symlinks
3. Merge Zed settings (`scripts/zed/zed-update-local.sh`)
4. Run doctor checks
5. Show result summary — highlight any issues, press any key to return

### Tools Menu

`gum choose` submenu with categories. Each category opens a second `gum choose` with its actions.

| Category | Actions |
|---|---|
| **Zed** | Merge settings / Diff base vs local / Promote change to base |
| **Symlinks** | Re-link all / Force update / Check status |
| **Fonts** | Install Nerd Fonts |
| **Secrets** | Check .local-secrets / Verify permissions / Show defined keys (not values) |

## gum Dependency Handling

On startup, `dotfiles.sh` checks for gum. If missing:
```
gum not found.
Install via: brew install gum  or  sudo apt install gum
Auto-install? [y/N]
```
If yes and on macOS: `brew install gum`. If on Debian/WSL: `sudo apt install gum`. Falls back to plain text output if install declined.

## gum Components Used

| gum command | Used for |
|---|---|
| `gum choose` | All menus and submenus |
| `gum choose --no-limit` | Install wizard multi-select |
| `gum confirm` | Destructive action confirmation |
| `gum spin` | Progress wrapper around scripts |
| `gum style` | Styled headers and status badges |
| `gum table` | Status display (future, optional) |

## What Is NOT Changing

- All existing scripts in `scripts/` remain unchanged — TUI calls them
- `bootstrap.sh` unchanged — still works headless for CI/server
- `scripts/zed/` scripts unchanged
- fzf usage in zsh (history, file search) unchanged
- `dotfiles.sh` command name unchanged

## Error Handling

- Each `gum spin` call captures exit code — on failure shows error output and `gum confirm "Continue anyway?"`.
- If gum is not available and user declines install, fall back to plain `echo` output with no interactive menus (graceful degradation).
- `set -euo pipefail` in each `tui/*.sh` file.

## Adding New Tools

New tool categories are added by:
1. Creating `tui/tools/<name>.sh`
2. Adding the category name to the tools menu in `dotfiles.sh`

No registration system needed — tools are discovered by the explicit list in the menu.

# dotfetch — Design Spec

**Date:** 2026-05-13  
**Status:** Approved

## Goal

A neofetch-style system info display for the Browolff dotfiles repo. Shows custom ASCII art + system stats + dotfiles-specific fields. Runs as a standalone command (`dotfetch`) and on terminal start via `.zshrc`.

---

## Architecture

### Files

| File | Action | Responsibility |
|---|---|---|
| `scripts/dotfetch.sh` | Create | Main script — ASCII art, stat collection, rendering |
| `scripts/audit.sh` | Create | Cleanup audit — dead symlinks, stale scripts, disabled module drift |
| `zsh/05-integrations.zsh` | Modify | Add `dotfetch` call on terminal start |
| symlinks config | Modify | Add `dotfetch` → `~/.local/bin/dotfetch` symlink entry |

### Invocation modes

| Invocation | Behavior |
|---|---|
| `dotfetch` | Full display, skip broken-symlink scan (fast path) |
| `dotfetch --full` | Full display + broken symlink count (slower) |
| `dotfetch --audit` | Delegates to `scripts/audit.sh` |
| Sourced from `.zshrc` | Calls `dotfetch` (fast path) |

---

## Layout

Two-column. Left: ASCII art (~24 cols, ~14 lines). Right: labeled stat pairs.

```
  [ASCII art]        christian@hostname
                     ──────────────────
                     OS       Arch Linux x86_64
                     Kernel   6.6.87-microsoft
                     Uptime   3h 42m
                     Shell    zsh 5.9
                     Terminal ghostty

                     ── dotfiles ──────
                     Version  v1.4.0
                     Branch   master ✓
                     Modules  15 / 17 enabled
                     Symlinks 42 total  0 broken

                     ████████████████
```

Color pulled from terminal capabilities. Falls back cleanly on dumb terminals (no ANSI codes emitted).

---

## ASCII Art

"BROWOLFF" rendered in compact block letters or a wolf motif — width ≤ 28 cols, height ≤ 16 lines. Stored as a heredoc in `dotfetch.sh`. Color: single accent color (cyan or green) matching the stat label color.

---

## Stats Fields

### System (standard neofetch subset)

| Field | Source | Method |
|---|---|---|
| `user@host` | `$USER`, `$HOSTNAME` / `hostname` | env var / built-in |
| OS | `/etc/os-release` (Linux) / `sw_vers` (macOS) | file read / subshell |
| Kernel | `uname -r` | single subprocess |
| Uptime | `/proc/uptime` (Linux) / `sysctl kern.boottime` (macOS) | file read / sysctl |
| Shell | `$SHELL` + version via `$ZSH_VERSION` etc. | env vars |
| Terminal | `$TERM_PROGRAM` or `$TERM` | env var |

### Dotfiles extras

| Field | Source | Method |
|---|---|---|
| Version | `$DOTFILES_DIR/VERSION` | file read |
| Branch | `git rev-parse --abbrev-ref HEAD` | git |
| Dirty | `git status --porcelain` | git |
| Modules | count dirs in `modules/`, parse `modules.conf` for `!` prefixes | bash glob + grep |
| Symlinks | count entries in symlinks module list | file read (fast path) |
| Broken symlinks | stat each symlink target | file stat (--full only) |

### Color swatch

16-color block using ANSI background codes — standard neofetch footer.

---

## Performance Budget

| Check | Target |
|---|---|
| Total (fast path, zshrc) | < 80ms |
| Total (--full, manual) | < 300ms |
| Any single check | < 30ms |

No piped chains of 3+ subprocesses. No `find` with recursive scan. Git calls limited to 2 max.

---

## Cleanup Audit (`scripts/audit.sh`)

Scans for:

1. **Dead symlinks** — targets in symlink config that don't exist in dotfiles
2. **Stale module refs** — entries in `modules.conf` for modules that no longer exist as dirs
3. **Disabled but present** — modules explicitly disabled (`!module`) that could be removed
4. **Zed-only code** — references to `zed` tooling given `!zed` in `modules.conf`
5. **Orphan scripts** — scripts in `scripts/` with no callers in dotfiles or Brewfile
6. **Broken symlinks on disk** — `~` symlinks pointing to missing dotfiles targets

Output: grouped report with severity tags (`stale`, `dead`, `unused`, `drift`). No auto-fix — report only, user decides.

---

## Cross-platform

| Platform | Notes |
|---|---|
| macOS | `sw_vers` for OS, `sysctl` for uptime |
| Linux / WSL | `/etc/os-release`, `/proc/uptime` |
| Headless (LinuxBro) | Skip color swatch if `$TERM == dumb` or no TTY |

Uses `_dotfiles_platform` from `modules/_lib/platform.sh` where needed.

---

## Out of Scope

- Interactive controls (that's `dotfiles.sh` / TUI)
- Auto-fix for audit findings
- Network checks
- Package manager counts (slow)

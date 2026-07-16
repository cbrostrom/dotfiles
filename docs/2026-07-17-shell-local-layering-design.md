# Shell .local Layering

**Date:** 2026-07-17
**Status:** Approved

## Problem

Machine-specific shell config (PATH, aliases, secrets) has no structured home. Users either hack the shared `.zshrc` (lost on next pull) or forget where overrides live.

## Solution

Add `.local` sourcing to `.zshrc` and `.zshenv`. Each machine gets its own `~/.zshrc.local` and `~/.zshenv.local` that are sourced at the end of the shared files. These files are native to each machine — never symlinked, never in the dotfiles repo.

## Design

### Sourcing

At the bottom of `.zshrc`:
```bash
# ── Machine-local overrides (not in dotfiles) ────────────────────────────────
[[ -f ~/.zshrc.local ]] && source ~/.zshrc.local
```

At the bottom of `.zshenv`:
```bash
# ── Machine-local overrides (not in dotfiles) ────────────────────────────────
[[ -f ~/.zshenv.local ]] && source ~/.zshenv.local
```

### Templates

Committed to repo:
- `zsh/zshrc.local.example` — freeform with soft section headers
- `zsh/zshenv.local.example` — env vars, PATH, secrets

### Bootstrap behavior

`scripts/install/symlinks.sh` creates `~/.zshrc.local` and `~/.zshenv.local` from templates on first run if they don't already exist. Existing files are never overwritten.

### Reset

No change — `.local` files aren't symlinks, so `bootstrap.sh --reset` never touches them.

## Related: Opencode Web Autostart

The opencode module now auto-enables the web UI service on `server-headless` profile machines (LinuxBro, SuperBro). Desktop machines can opt in via `opencode-web-autostart` in modules.conf.

## Scope

- Shell only (`.zshrc`, `.zshenv`)
- Future: could extend to `opencode.json.local`, `starship.toml.local` if pattern proves useful

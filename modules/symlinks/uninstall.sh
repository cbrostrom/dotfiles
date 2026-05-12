#!/usr/bin/env bash
set -euo pipefail
. "$DOTFILES_DIR/modules/_lib/log.sh"
. "$DOTFILES_DIR/modules/_lib/unlink.sh"

log "removing dotfile symlinks (only those resolving into $DOTFILES_DIR)…"

# Walk roots that the install side may have populated. Anything not pointing
# into $DOTFILES_DIR is left alone.
unlink_roots \
    "$HOME" \
    "$HOME/.config" \
    "$HOME/.codex" \
    "$HOME/.cursor"

# Git hooks symlinks live inside the repo itself — best left in place; they
# regenerate on install.

ok "symlink reset complete"

#!/usr/bin/env bash
set -euo pipefail
. "$DOTFILES_DIR/modules/_lib/log.sh"
. "$DOTFILES_DIR/modules/_lib/unlink.sh"

roots=(
    "$HOME/.config/zed"
    "$HOME/Library/Application Support/Zed"
)

log "removing Zed config symlinks…"
unlink_roots "${roots[@]}"
ok "Zed config reset complete"

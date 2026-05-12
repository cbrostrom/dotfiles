#!/usr/bin/env bash
set -euo pipefail
. "$DOTFILES_DIR/modules/_lib/log.sh"
. "$DOTFILES_DIR/modules/_lib/unlink.sh"

# VSCodium config locations vary by OS — walk all candidates; non-existent ones
# are silently skipped by unlink_roots.
roots=(
    "$HOME/.config/VSCodium/User"
    "$HOME/Library/Application Support/VSCodium/User"
    "${APPDATA:-}/VSCodium/User"
)

log "removing VSCodium config symlinks…"
unlink_roots "${roots[@]}"
ok "VSCodium config reset complete"

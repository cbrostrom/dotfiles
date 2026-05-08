#!/usr/bin/env bash
set -euo pipefail
. "$DOTFILES_DIR/modules/_lib/log.sh"

if [[ ! -x "$DOTFILES_DIR/scripts/vscodium/install-vscodium-config.sh" ]]; then
    warn "scripts/vscodium/install-vscodium-config.sh not present — nothing to do"
    exit 0
fi
log "installing VSCodium config …"
bash "$DOTFILES_DIR/scripts/vscodium/install-vscodium-config.sh" --config \
    || warn "VSCodium config install had errors (non-fatal)"

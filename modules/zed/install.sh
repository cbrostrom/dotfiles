#!/usr/bin/env bash
set -euo pipefail
. "$DOTFILES_DIR/modules/_lib/log.sh"

if [[ ! -x "$DOTFILES_DIR/scripts/zed/install-zed-config.sh" ]]; then
    warn "scripts/zed/install-zed-config.sh not present — nothing to do"
    exit 0
fi
log "installing Zed config …"
bash "$DOTFILES_DIR/scripts/zed/install-zed-config.sh" || warn "Zed config install had errors (non-fatal)"

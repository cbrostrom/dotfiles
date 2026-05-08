#!/usr/bin/env bash
set -euo pipefail
. "$DOTFILES_DIR/modules/_lib/log.sh"

if [[ ! -x "$DOTFILES_DIR/scripts/install/secrets.sh" ]]; then
    warn "scripts/install/secrets.sh not present — nothing to do"
    exit 0
fi
log "configuring local secrets …"
bash "$DOTFILES_DIR/scripts/install/secrets.sh" || warn "secrets install had errors (non-fatal)"

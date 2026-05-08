#!/usr/bin/env bash
set -euo pipefail
. "$DOTFILES_DIR/modules/_lib/log.sh"

if [[ ! -x "$DOTFILES_DIR/scripts/install/beets.sh" ]]; then
    warn "scripts/install/beets.sh not present — nothing to do"
    exit 0
fi
log "installing beets …"
bash "$DOTFILES_DIR/scripts/install/beets.sh" || warn "beets install had errors (non-fatal)"

#!/usr/bin/env bash
set -euo pipefail
. "$DOTFILES_DIR/modules/_lib/log.sh"

if [[ ! -x "$DOTFILES_DIR/scripts/install/rbw.sh" ]]; then
    warn "scripts/install/rbw.sh not present — nothing to do"
    exit 0
fi
log "configuring rbw (Bitwarden CLI) …"
bash "$DOTFILES_DIR/scripts/install/rbw.sh" || warn "rbw setup reported errors (non-fatal)"

#!/usr/bin/env bash
set -euo pipefail
. "$DOTFILES_DIR/modules/_lib/log.sh"

if [[ ! -x "$DOTFILES_DIR/scripts/install/ssh-superbro.sh" ]]; then
    warn "ssh-superbro.sh not present — nothing to do"
    exit 0
fi
log "configuring SSH for superbro …"
bash "$DOTFILES_DIR/scripts/install/ssh-superbro.sh" || warn "ssh superbro setup reported errors (non-fatal)"

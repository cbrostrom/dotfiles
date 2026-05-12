#!/usr/bin/env bash
set -euo pipefail
. "$DOTFILES_DIR/modules/_lib/log.sh"

log "installing starship …"
bash "$DOTFILES_DIR/scripts/install/starship.sh" || warn "starship install reported errors (non-fatal)"

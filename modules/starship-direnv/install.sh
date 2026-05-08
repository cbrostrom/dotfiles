#!/usr/bin/env bash
set -euo pipefail
. "$DOTFILES_DIR/modules/_lib/log.sh"

log "installing starship + direnv …"
bash "$DOTFILES_DIR/scripts/install/starship-direnv.sh" || warn "starship/direnv install reported errors (non-fatal)"

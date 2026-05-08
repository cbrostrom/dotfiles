#!/usr/bin/env bash
set -euo pipefail
. "$DOTFILES_DIR/modules/_lib/log.sh"

log "installing Nerd Font …"
bash "$DOTFILES_DIR/scripts/install/nerd-fonts.sh" || warn "font install failed (non-fatal)"

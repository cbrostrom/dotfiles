#!/usr/bin/env bash
set -euo pipefail
. "$DOTFILES_DIR/modules/_lib/log.sh"

log "ensuring zellij is installed …"
bash "$DOTFILES_DIR/scripts/install/zellij.sh" || warn "zellij install reported errors (non-fatal)"

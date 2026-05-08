#!/usr/bin/env bash
set -euo pipefail
. "$DOTFILES_DIR/modules/_lib/log.sh"

if [[ ! -x "$DOTFILES_DIR/macos/defaults.sh" ]]; then
    warn "macos/defaults.sh not present — nothing to do"
    exit 0
fi
log "applying macOS defaults …"
bash "$DOTFILES_DIR/macos/defaults.sh" || warn "macOS defaults reported errors"

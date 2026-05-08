#!/usr/bin/env bash
set -euo pipefail
. "$DOTFILES_DIR/modules/_lib/log.sh"
log "creating symlinks …"
bash "$DOTFILES_DIR/scripts/install/symlinks.sh"

#!/usr/bin/env bash
set -euo pipefail
. "$DOTFILES_DIR/modules/_lib/log.sh"

if [[ ! -x "$DOTFILES_DIR/scripts/install/engram.sh" ]]; then
    warn "scripts/install/engram.sh not present — nothing to do"
    exit 0
fi
log "configuring engram (memory MCP + git sync) …"
bash "$DOTFILES_DIR/scripts/install/engram.sh" || warn "engram setup reported errors (non-fatal)"

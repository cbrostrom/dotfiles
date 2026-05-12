#!/usr/bin/env bash
set -euo pipefail
. "$DOTFILES_DIR/modules/_lib/log.sh"
. "$DOTFILES_DIR/modules/_lib/unlink.sh"

log "removing Claude Code config symlinks (~/.claude only)…"
unlink_roots "$HOME/.claude"
ok "Claude config reset complete"

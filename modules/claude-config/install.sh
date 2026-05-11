#!/usr/bin/env bash
set -euo pipefail
. "$DOTFILES_DIR/modules/_lib/log.sh"

log "installing Claude Code config (settings, CLAUDE.md, hooks, skills) …"
bash "$DOTFILES_DIR/scripts/claude/install-claude-config.sh"

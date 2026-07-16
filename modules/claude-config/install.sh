#!/usr/bin/env bash
set -euo pipefail
. "$DOTFILES_DIR/modules/_lib/log.sh"

log "installing Claude Code config (settings, CLAUDE.md, hooks, skills) …"
bash "$DOTFILES_DIR/scripts/claude/install-claude-config.sh"

# Ensure Cursor config is also applied (paritied for WSL)
if [[ -d "$DOTFILES_DIR/.cursor" ]]; then
    log "installing Cursor config (rules, hooks) …"
    bash "$DOTFILES_DIR/scripts/cursor/install-cursor-config.sh"
fi

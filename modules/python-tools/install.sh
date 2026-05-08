#!/usr/bin/env bash
set -euo pipefail
. "$DOTFILES_DIR/modules/_lib/log.sh"

log "installing Python MCP tools via pipx …"
pipx install mcp-atlassian 2>/dev/null \
    || pipx upgrade mcp-atlassian 2>/dev/null \
    || warn "mcp-atlassian install failed (non-fatal)"
ok "mcp-atlassian ready: $(command -v mcp-atlassian 2>/dev/null || echo 'not found')"

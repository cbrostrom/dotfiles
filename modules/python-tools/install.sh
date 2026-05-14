#!/usr/bin/env bash
set -euo pipefail
. "$DOTFILES_DIR/modules/_lib/log.sh"

log "installing Python MCP tools via pipx …"
pipx install mcp-atlassian 2>/dev/null \
    || pipx upgrade mcp-atlassian 2>/dev/null \
    || warn "mcp-atlassian install failed (non-fatal)"
ok "mcp-atlassian ready: $(command -v mcp-atlassian 2>/dev/null || echo 'not found')"

# uv / uvx — used by docker MCP wrappers (~/.claude/scripts/docker-*.sh)
if command -v uvx >/dev/null 2>&1; then
    ok "uv already installed: $(command -v uvx)"
else
    log "installing uv (provides uvx) …"
    if pipx install uv 2>/dev/null; then
        :
    else
        curl -LsSf https://astral.sh/uv/install.sh | sh 2>/dev/null \
            || warn "uv install failed (non-fatal)"
    fi
    ok "uv ready: $(command -v uvx 2>/dev/null || echo "$HOME/.local/bin/uvx (post-install PATH refresh needed)")"
fi

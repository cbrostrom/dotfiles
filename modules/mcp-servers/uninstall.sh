#!/usr/bin/env bash
set -euo pipefail
. "$DOTFILES_DIR/modules/_lib/log.sh"
. "$DOTFILES_DIR/modules/_lib/lists.sh"

base="$DOTFILES_DIR/.claude/mcp-servers.list"
if [[ ! -f "$base" ]] || ! command -v claude >/dev/null 2>&1; then
    warn "claude CLI or mcp-servers.list not available — skipping"
    exit 0
fi

log "removing Claude Code MCP servers registered from this dotfiles config…"

while IFS='|' read -r name _rest || [[ -n "$name" ]]; do
    name="${name// /}"
    [[ -z "$name" ]] && continue
    if [[ "${UNLINK_DRY_RUN:-0}" == "1" ]]; then
        echo "  would: claude mcp remove $name --scope user"
    else
        claude mcp remove "$name" --scope user >/dev/null 2>&1 \
            && ok "  removed MCP: $name" \
            || warn "  could not remove MCP: $name (may already be gone)"
    fi
done < <(lists_merge "$base")

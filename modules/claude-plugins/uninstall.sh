#!/usr/bin/env bash
set -euo pipefail
. "$DOTFILES_DIR/modules/_lib/log.sh"
. "$DOTFILES_DIR/modules/_lib/lists.sh"

base="$DOTFILES_DIR/.claude/plugins.list"
if [[ ! -f "$base" ]] || ! command -v claude >/dev/null 2>&1; then
    warn "claude CLI or plugins.list not available — skipping"
    exit 0
fi

log "uninstalling Claude Code plugins listed in this dotfiles config…"

while IFS= read -r line || [[ -n "$line" ]]; do
    plugin_ref="${line%%=*}"
    plugin_ref="${plugin_ref//[[:space:]]/}"
    [[ "$plugin_ref" != *@* ]] && continue
    if [[ "${UNLINK_DRY_RUN:-0}" == "1" ]]; then
        echo "  would: claude plugin uninstall $plugin_ref --scope user"
    else
        claude plugin uninstall "$plugin_ref" --scope user >/dev/null 2>&1 \
            && ok "  uninstalled plugin: $plugin_ref" \
            || warn "  could not uninstall plugin: $plugin_ref"
    fi
done < <(lists_merge "$base")

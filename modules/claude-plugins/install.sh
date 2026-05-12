#!/usr/bin/env bash
set -euo pipefail
. "$DOTFILES_DIR/modules/_lib/log.sh"

list="$DOTFILES_DIR/.claude/plugins.list"
[[ -f "$list" ]] || { warn "plugins.list not found at $list"; exit 0; }

log "installing Claude Code plugins from $list …"

# Cache marketplace + installed plugin lists once
mkts="$(claude plugin marketplace list 2>/dev/null || true)"
plugs="$(claude plugin list 2>/dev/null || true)"

while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%%#*}"
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"
    [[ -z "$line" ]] && continue

    plugin_ref="${line%%=*}"
    source_ref="${line#*=}"
    plugin_ref="${plugin_ref//[[:space:]]/}"
    source_ref="${source_ref//[[:space:]]/}"

    [[ "$plugin_ref" != *@* ]] && { warn "invalid entry (need plugin@marketplace): $line"; continue; }
    marketplace="${plugin_ref#*@}"
    plugin_name="${plugin_ref%@*}"

    if ! grep -qE "❯[[:space:]]+${marketplace}([[:space:]]|$)" <<< "$mkts"; then
        if claude plugin marketplace add "$source_ref" >/dev/null 2>&1; then
            ok "marketplace added: $marketplace ($source_ref)"
            mkts="$(claude plugin marketplace list 2>/dev/null || true)"
        else
            warn "marketplace add failed: $marketplace ($source_ref)"
            continue
        fi
    fi

    if grep -qE "❯[[:space:]]+${plugin_name}@${marketplace}([[:space:]]|$)" <<< "$plugs"; then
        ok "plugin already installed: $plugin_ref"
        continue
    fi

    if claude plugin install "$plugin_ref" --scope user >/dev/null 2>&1; then
        ok "plugin installed: $plugin_ref"
    else
        warn "plugin install failed: $plugin_ref"
    fi
done < "$list"

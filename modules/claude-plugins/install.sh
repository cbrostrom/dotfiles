#!/usr/bin/env bash
set -euo pipefail
. "$DOTFILES_DIR/modules/_lib/log.sh"
. "$DOTFILES_DIR/modules/_lib/lists.sh"

base="$DOTFILES_DIR/.claude/plugins.list"
[[ -f "$base" ]] || { warn "plugins.list not found at $base"; exit 0; }

overlays="$(lists_active_paths "$base" | xargs -n1 basename 2>/dev/null | tr '\n' ' ')"
log "installing Claude Code plugins (layers: ${overlays})…"

# Cache marketplace + installed plugin lists once
mkts="$(claude plugin marketplace list 2>/dev/null || true)"
plugs="$(claude plugin list 2>/dev/null || true)"

while IFS= read -r line || [[ -n "$line" ]]; do
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
done < <(lists_merge "$base")

# Remove plugins installed but no longer in any active list layer.
desired="$(lists_merge "$base" | sed 's/=.*//' | tr -d ' ')"
while IFS= read -r installed_spec; do
    [[ -n "$installed_spec" ]] || continue
    if ! grep -qF "$installed_spec" <<< "$desired"; then
        if claude plugin uninstall "$installed_spec" --scope user >/dev/null 2>&1; then
            ok "plugin removed (not in active list): $installed_spec"
        fi
    fi
done < <(claude plugin list 2>/dev/null | grep -oE '[^[:space:]]+@[^[:space:]]+' || true)

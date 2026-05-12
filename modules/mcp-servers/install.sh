#!/usr/bin/env bash
set -euo pipefail
. "$DOTFILES_DIR/modules/_lib/log.sh"
. "$DOTFILES_DIR/modules/_lib/lists.sh"

base="$DOTFILES_DIR/.claude/mcp-servers.list"
[[ -f "$base" ]] || { warn "mcp-servers.list not found at $base"; exit 0; }

overlays="$(lists_active_paths "$base" | xargs -n1 basename 2>/dev/null | tr '\n' ' ')"
log "registering Claude Code MCP servers (layers: ${overlays})…"

while IFS='|' read -r name command args_rest || [[ -n "$name" ]]; do
    name="${name// /}"
    [[ -z "$name" ]] && continue
    command="${command// /}"
    command="${command/#\~/$HOME}"
    [[ -z "$command" ]] && { warn "MCP entry '$name' missing command — skipping"; continue; }

    IFS='|' read -ra arg_tokens <<< "$args_rest"
    args=()
    for t in "${arg_tokens[@]}"; do
        t="${t# }"; t="${t% }"
        [[ -n "$t" ]] && args+=("$t")
    done

    claude mcp remove "$name" --scope user 2>/dev/null || true
    if [[ "$command" == "http" ]]; then
        if claude mcp add --transport http --scope user "$name" "${args[0]}" 2>/dev/null; then
            ok "MCP registered (http): $name"
        else
            warn "MCP registration failed: $name"
        fi
    else
        if claude mcp add --scope user "$name" -- "$command" "${args[@]}" 2>/dev/null; then
            ok "MCP registered: $name"
        else
            warn "MCP registration failed: $name"
        fi
    fi
done < <(lists_merge "$base")

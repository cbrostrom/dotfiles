#!/usr/bin/env bash
# project-mcp — add/remove project-scoped MCP servers in .claude/settings.json
#
# Usage (run from project root):
#   project-mcp add akqa          — Atlassian (AKQA workspace)
#   project-mcp add fiskars       — Atlassian (Fiskars workspace)
#   project-mcp add shopify       — Shopify dev MCP
#   project-mcp remove <name>     — remove a server
#   project-mcp list              — show current project MCPs
#   project-mcp clear             — remove all project MCPs
#
# Writes to ./.claude/settings.json (Claude Code project scope).
# Idempotent — safe to re-run.

set -euo pipefail

if ! command -v jq >/dev/null 2>&1; then
    echo "jq required — brew install jq" >&2; exit 1
fi

SETTINGS_FILE=".claude/settings.json"
mkdir -p .claude

_read_settings() {
    if [[ -f "$SETTINGS_FILE" ]]; then
        cat "$SETTINGS_FILE"
    else
        echo '{}'
    fi
}

_write_settings() {
    local json="$1"
    echo "$json" | jq '.' > "$SETTINGS_FILE"
    echo "→ $SETTINGS_FILE updated"
}

_mcp_entry() {
    local name="$1"
    case "$name" in
        akqa)
            jq -n --arg cmd "$HOME/.claude/scripts/atlassian-akqa.sh" \
                '{"atlassian-akqa": {"type": "stdio", "command": $cmd, "args": []}}'
            ;;
        fiskars)
            jq -n --arg cmd "$HOME/.claude/scripts/atlassian-fiskars.sh" \
                '{"atlassian-fiskars": {"type": "stdio", "command": $cmd, "args": []}}'
            ;;
        shopify)
            jq -n '{"shopify-dev": {"type": "stdio", "command": "npx", "args": ["-y", "@shopify/dev-mcp@latest"]}}'
            ;;
        *)
            echo "Unknown profile: $name" >&2
            echo "Available: akqa, fiskars, shopify" >&2
            exit 1
            ;;
    esac
}

cmd="${1:-list}"
shift || true

case "$cmd" in
    add)
        [[ -z "${1:-}" ]] && { echo "Usage: project-mcp add <profile>"; exit 1; }
        profile="$1"
        entry="$(_mcp_entry "$profile")"
        current="$(_read_settings)"
        merged="$(echo "$current" | jq --argjson e "$entry" '.mcpServers = (.mcpServers // {} | . + $e)')"
        _write_settings "$merged"
        key="$(echo "$entry" | jq -r 'keys[0]')"
        echo "✓ Added $key"
        ;;

    remove)
        [[ -z "${1:-}" ]] && { echo "Usage: project-mcp remove <server-name>"; exit 1; }
        key="$1"
        current="$(_read_settings)"
        merged="$(echo "$current" | jq --arg k "$key" 'del(.mcpServers[$k])')"
        _write_settings "$merged"
        echo "✓ Removed $key"
        ;;

    list)
        if [[ ! -f "$SETTINGS_FILE" ]]; then
            echo "No project MCPs configured (.claude/settings.json absent)"
        else
            echo "Project MCPs in $SETTINGS_FILE:"
            jq -r '.mcpServers // {} | to_entries[] | "  • \(.key)"' "$SETTINGS_FILE"
        fi
        ;;

    clear)
        current="$(_read_settings)"
        merged="$(echo "$current" | jq 'del(.mcpServers)')"
        _write_settings "$merged"
        echo "✓ Cleared all project MCPs"
        ;;

    *)
        echo "Usage: project-mcp <add|remove|list|clear> [profile|server-name]"
        exit 1
        ;;
esac

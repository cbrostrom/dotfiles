# =============================================================================
# CMUX HELPERS — Orchestration bridge for cmux embedded browser & actions
# =============================================================================
# These helpers enable cmux.json actions to trigger complex browser flows
# and environment-aware URL openings.
# =============================================================================

# -----------------------------------------------------------------------------
# cmux-open <url>
# Opens a URL in the cmux embedded browser. Handles env var expansion.
# -----------------------------------------------------------------------------
cmux-open() {
    local url="$1"
    if [[ -z "$url" ]]; then
        echo "Usage: cmux-open <url>"
        return 1
    fi
    # Expand environment variables in the URL if present
    url=$(eval echo "$url")
    cmux open "$url"
}

# -----------------------------------------------------------------------------
# cmadmin <store_handle>
# Opens the Shopify Admin for the specified store handle.
# Example: cmadmin iittala-dev -> https://iittala-dev.myshopify.com/admin
# -----------------------------------------------------------------------------
cmadmin() {
    local store="$1"
    if [[ -z "$store" ]]; then
        echo "Usage: cmadmin <store_handle>"
        return 1
    fi
    cmux-open "https://${store}.myshopify.com/admin"
}

# -----------------------------------------------------------------------------
# cmtheme <store_handle>
# Opens the Shopify Theme Editor for the specified store handle.
# Example: cmtheme iittala-dev -> https://iittala-dev.myshopify.com/admin/themes/current/editor
# -----------------------------------------------------------------------------
cmtheme() {
    local store="$1"
    if [[ -z "$store" ]]; then
        echo "Usage: cmtheme <store_handle>"
        return 1
    fi
    cmux-open "https://${store}.myshopify.com/admin/themes/current/editor"
}

# -----------------------------------------------------------------------------
# cmux-agent-workspace <name> [path]
# Launch a workspace with a split Terminal | Agent layout.
# -----------------------------------------------------------------------------
cmux-agent-workspace() {
    local name="$1"
    local path="${2:-.}"
    local layout='{"direction":"horizontal","split":0.5,"children":[{"pane":{"surfaces":[{"type":"terminal"}]}},{"pane":{"surfaces":[{"type":"agent-session"}]}}]}'
    cmux new-workspace --name "$name" --cwd "$path" --layout "$layout" --focus true
}

# -----------------------------------------------------------------------------
# cmux-workspace <name> <layout_json>
# Create a workspace with a custom layout JSON.
# -----------------------------------------------------------------------------
cmux-workspace() {
    local name="$1"
    local layout="$2"
    if [[ -z "$name" || -z "$layout" ]]; then
        echo "Usage: cmux-workspace <name> <layout_json>"
        return 1
    fi
    cmux new-workspace --name "$name" --focus true --layout "$layout"
}

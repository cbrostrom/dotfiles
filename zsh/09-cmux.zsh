# =============================================================================
# CMUX — sidebar status integration + helpers (loads only inside cmux)
# =============================================================================
# Active only when $CMUX_WORKSPACE_ID is set (i.e. running inside a cmux pane).
# Updates the sidebar status pill with current project + git branch on every
# `cd`, so the workspace row tells you where each pane is without opening it.
# =============================================================================

# Bail out fast outside cmux (no overhead).
[[ -z "$CMUX_WORKSPACE_ID" ]] && return
command -v cmux >/dev/null 2>&1 || return

# Update sidebar status pill: "<dirname>@<branch>" or just "<dirname>".
# Runs in background so chpwd stays snappy.
__cmux_status() {
    {
        local dir branch label
        dir="${PWD:t}"
        [[ "$PWD" == "$HOME" ]] && dir="~"
        if [[ -d .git ]] || git -C "$PWD" rev-parse --git-dir >/dev/null 2>&1; then
            branch=$(git -C "$PWD" symbolic-ref --short HEAD 2>/dev/null)
        fi
        if [[ -n "$branch" ]]; then
            label="${dir}@${branch}"
        else
            label="$dir"
        fi
        cmux set-status project "$label" --icon "folder.fill" --color "#4C8DFF" >/dev/null 2>&1
    } &!
}

# Run once on shell start + on every cd.
autoload -Uz add-zsh-hook
add-zsh-hook chpwd __cmux_status
__cmux_status

# -----------------------------------------------------------------------------
# Manual helpers (CLI conveniences — palette shortcuts live in cmux.json)
# -----------------------------------------------------------------------------

# cmux-status <key> <value>  — set arbitrary pill from any script.
cmst() { cmux set-status "$1" "$2" --icon "${3:-info.circle}" --color "${4:-#4C8DFF}" }

# cmux-progress <0..1> [label]  — set progress bar.
cmpr() { cmux set-progress "$1" --label "${2:-Working...}" }

# cmux-log <message> [level]  — append log line to sidebar.
cmlog() { cmux log --level "${2:-info}" -- "$1" }

# cmux-clear [key]  — wipe a sidebar status pill (default: project).
cmclr() { cmux clear-status "${1:-project}" >/dev/null 2>&1 }

# cmux-open <url>  — open URL in a new cmux embedded-browser surface.
# Used by palette actions that want to launch URLs (admin panels, Jira boards).
cmux-open() { cmux new-surface --type browser --url "$1" --focus true >/dev/null 2>&1 }

# Shopify admin shorthand: cmadmin <store-handle>  (handle = "iittala-dev" etc.)
cmadmin() { cmux-open "https://${1}.myshopify.com/admin" }

# Shopify theme editor shorthand: cmtheme <store-handle>
cmtheme() { cmux-open "https://${1}.myshopify.com/admin/themes/current/editor" }

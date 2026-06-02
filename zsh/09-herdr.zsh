# shellcheck shell=bash
# =============================================================================
# HERDR — pane label + workspace integration (loads only inside herdr)
# =============================================================================
# Active only when $HERDR_PANE_ID is set (i.e. running inside a herdr pane).
# Renames the current pane to "<dirname>@<branch>" on every `cd` so the
# workspace overview tells you where each pane is without opening it.
# =============================================================================

# Bail out fast outside herdr (no overhead).
[[ -z "$HERDR_PANE_ID" ]] && return
command -v herdr >/dev/null 2>&1 || return

# Rename current pane: "<dirname>@<branch>" or just "<dirname>".
# Runs in background so chpwd stays snappy.
__herdr_pane_label() {
    {
        local dir branch label
        dir="${PWD:t}"
        [[ "$PWD" == "$HOME" ]] && dir="~"
        if git -C "$PWD" rev-parse --git-dir >/dev/null 2>&1; then
            branch=$(git -C "$PWD" symbolic-ref --short HEAD 2>/dev/null)
        fi
        if [[ -n "$branch" ]]; then
            label="${dir}@${branch}"
        else
            label="$dir"
        fi
        herdr pane rename "$HERDR_PANE_ID" "$label" >/dev/null 2>&1
    } &!
}

autoload -Uz add-zsh-hook
add-zsh-hook chpwd __herdr_pane_label
__herdr_pane_label

# -----------------------------------------------------------------------------
# Helpers
# -----------------------------------------------------------------------------

# hpane <label>  — manually rename this pane.
hpane() { herdr pane rename "$HERDR_PANE_ID" "$1" >/dev/null 2>&1 }

# hws <label>  — rename current workspace.
hws() { herdr workspace rename "$HERDR_WORKSPACE_ID" "$1" >/dev/null 2>&1 }

# hnew [cwd]  — open new workspace (optional path, defaults to cwd).
hnew() { herdr workspace create --cwd "${1:-$PWD}" --focus >/dev/null 2>&1 }

# hsplit [direction]  — split current pane right (or down).
hsplit() { herdr pane split "$HERDR_PANE_ID" --direction "${1:-right}" --focus >/dev/null 2>&1 }

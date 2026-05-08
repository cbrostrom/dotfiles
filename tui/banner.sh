#!/usr/bin/env bash
# Persistent banner + status row, reused across all TUI screens.
# Source me; do not exec.

DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

# Module-system context for status counts.
. "$DOTFILES_DIR/modules/_lib/log.sh"        2>/dev/null
. "$DOTFILES_DIR/modules/_lib/platform.sh"   2>/dev/null
. "$DOTFILES_DIR/modules/_lib/config.sh"     2>/dev/null
. "$DOTFILES_DIR/modules/_lib/loader.sh"     2>/dev/null

_banner_module_counts() {
    DOTFILES_QUIET=1 modules_init       >/dev/null 2>&1 || return
    DOTFILES_QUIET=1 modules_discover   >/dev/null 2>&1 || return
    local name action status
    local -i clean=0 dirty=0 unkn=0 off=0 na=0
    while IFS= read -r name; do
        action="$(_decide_module_action "$name")"
        status="$(modules_status "$name")"
        case "$action" in
            run)
                case "$status" in
                    clean)   clean=$((clean+1)) ;;
                    dirty)   dirty=$((dirty+1)) ;;
                    *)       unkn=$((unkn+1)) ;;
                esac ;;
            skip-platform|skip-profile)            na=$((na+1)) ;;
            skip-disabled|skip-not-selected)       off=$((off+1)) ;;
            skip-missing-req:*)                    off=$((off+1)) ;;
        esac
    done < <(modules_list_all)
    echo "$clean $dirty $unkn $off $na"
}

_banner_last_update() {
    local fh="$DOTFILES_DIR/.git/FETCH_HEAD"
    if [[ -f "$fh" ]]; then
        local ts now diff
        ts=$(stat -c '%Y' "$fh" 2>/dev/null || stat -f '%m' "$fh" 2>/dev/null)
        now=$(date +%s)
        diff=$(( (now - ts) ))
        if   (( diff < 60     )); then echo "just now"
        elif (( diff < 3600   )); then echo "$(( diff / 60 ))m ago"
        elif (( diff < 86400  )); then echo "$(( diff / 3600 ))h ago"
        else                            echo "$(( diff / 86400 ))d ago"
        fi
    else
        echo "never"
    fi
}

# Render the banner. Caller is responsible for `clear` first when redrawing.
render_banner() {
    local version git_hash plat prof updated
    version="$(cat "$DOTFILES_DIR/VERSION" 2>/dev/null || echo "?")"
    git_hash="$(git -C "$DOTFILES_DIR" rev-parse --short HEAD 2>/dev/null || echo "?")"
    plat="$(platform_tag)"
    prof="$(profile_tag)"
    updated="$(_banner_last_update)"

    # Centered logo with double border.
    gum style \
        --align center \
        --border double \
        --border-foreground 220 \
        --foreground 220 \
        --bold \
        --padding "0 4" \
        --margin "0" \
        "D O T F I L E S"

    # Meta row — version · hash · platform · profile · updated.
    gum style --align center --foreground 8 --margin "0" \
        "v${version}  ·  ${git_hash}  ·  ${plat}/${prof}  ·  updated ${updated}"

    # Module status row — colored glyphs.
    read -r clean dirty unkn off na < <(_banner_module_counts)
    printf "\n  \033[2mmodules\033[0m   \033[32m✓\033[0m %2d clean   \033[33m⚠\033[0m %2d dirty   \033[2m?\033[0m %2d unknown   \033[2m⊘\033[0m %2d off   \033[31m─\033[0m %2d N/A\n\n" \
        "$clean" "$dirty" "$unkn" "$off" "$na"
}

# Render a centered subtitle for sub-screens (Install / Update / Tools / etc.).
render_subtitle() {
    local title="$1"
    gum style \
        --align center \
        --foreground 220 \
        --bold \
        --margin "0 0 1 0" \
        "── $title ──"
}

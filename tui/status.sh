#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

_check_symlink() {
    local target="$1"
    [[ -L "$target" ]] && echo "ok" || { [[ -e "$target" ]] && echo "warn" || echo "fail"; }
}

_check_zed() {
    local zed_dir
    if [[ "$(uname -s)" == "Darwin" ]]; then
        zed_dir="$HOME/Library/Application Support/Zed"
    elif grep -qi microsoft /proc/version 2>/dev/null; then
        local win_user="${USERNAME:-$(whoami)}"
        zed_dir="/mnt/c/Users/$win_user/AppData/Roaming/Zed"
    else
        zed_dir="$HOME/.config/zed"
    fi
    # On WSL we copy (not symlink) settings.json — accept either
    if grep -qi microsoft /proc/version 2>/dev/null; then
        [[ -f "$zed_dir/settings.json" ]] && echo "ok" || echo "fail"
    else
        [[ -L "$zed_dir/settings.json" ]] && echo "ok" || echo "fail"
    fi
}

_check_secrets() {
    [[ -f "$HOME/.local-secrets" ]] || { echo "fail"; return; }
    local perms
    perms=$(stat -L -c '%a' "$HOME/.local-secrets" 2>/dev/null || stat -L -f '%Lp' "$HOME/.local-secrets" 2>/dev/null)
    [[ "$perms" == "600" ]] && echo "ok" || echo "warn"
}

_check_node() {
    command -v node >/dev/null 2>&1 && echo "ok" || echo "fail"
}

_check_git() {
    git config --global user.email >/dev/null 2>&1 && echo "ok" || echo "warn"
}

_last_update() {
    local fetch_head="$DOTFILES_DIR/.git/FETCH_HEAD"
    if [[ -f "$fetch_head" ]]; then
        local ts now diff
        ts=$(stat -c '%Y' "$fetch_head" 2>/dev/null || stat -f '%m' "$fetch_head" 2>/dev/null)
        now=$(date +%s)
        diff=$(( (now - ts) / 86400 ))
        echo "${diff}d ago"
    else
        echo "never"
    fi
}

_badge() {
    local status="$1" label="$2" detail="$3"
    case "$status" in
        ok)   gum style --foreground 10  "  ✓ $(printf '%-14s' "$label") $detail" ;;
        warn) gum style --foreground 11  "  ⚠ $(printf '%-14s' "$label") $detail" ;;
        fail) gum style --foreground 9   "  ✗ $(printf '%-14s' "$label") $detail" ;;
    esac
}

show_status() {
    local zsh_st git_st zed_st sec_st node_st
    zsh_st=$(_check_symlink "$HOME/.zshrc")
    git_st=$(_check_git)
    zed_st=$(_check_zed)
    sec_st=$(_check_secrets)
    node_st=$(_check_node)
    local last
    last=$(_last_update)

    gum style --bold --foreground 220 "STATUS"
    _badge "$zsh_st"  "zsh"     "$([[ $zsh_st  == ok ]] && echo linked   || echo "not linked")"
    _badge "$git_st"  "git"     "$([[ $git_st  == ok ]] && echo configured || echo "check gitconfig")"
    _badge "$zed_st"  "zed"     "$([[ $zed_st  == ok ]] && echo synced   || echo "not synced")"
    _badge "$sec_st"  "secrets" "$([[ $sec_st  == ok ]] && echo ok || { [[ $sec_st == warn ]] && echo "bad perms" || echo "missing"; })"
    _badge "$node_st" "node"    "$(command -v node >/dev/null 2>&1 && node --version 2>/dev/null || echo "not found")"
    gum style --foreground 8 "  last update: $last"
    echo
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    show_status
fi

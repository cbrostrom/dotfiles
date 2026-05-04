#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

_check_symlink() {
    local target="$1"
    [[ -L "$target" ]] && echo "ok" || { [[ -e "$target" ]] && echo "warn" || echo "fail"; }
}

_zed_target_dir() {
    if [[ "$(uname -s)" == "Darwin" ]]; then
        echo "$HOME/Library/Application Support/Zed"
    elif grep -qi microsoft /proc/version 2>/dev/null; then
        local win_user="${USERNAME:-$(whoami)}"
        echo "/mnt/c/Users/$win_user/AppData/Roaming/Zed"
    else
        echo "$HOME/.config/zed"
    fi
}

_check_zed() {
    local zed_dir
    zed_dir="$(_zed_target_dir)"
    if grep -qi microsoft /proc/version 2>/dev/null; then
        [[ -f "$zed_dir/settings.json" ]] && echo "ok" || echo "fail"
    else
        [[ -L "$zed_dir/settings.json" ]] && echo "ok" || echo "fail"
    fi
}

_zed_drift() {
    grep -qi microsoft /proc/version 2>/dev/null || return 0
    local zed_dir zed_src drifted=()
    zed_dir="$(_zed_target_dir)"
    zed_src="$DOTFILES_DIR/.config/zed"
    for f in keymap.json tasks.json; do
        [[ -f "$zed_dir/$f" && -f "$zed_src/$f" ]] || continue
        diff -q "$zed_src/$f" "$zed_dir/$f" >/dev/null 2>&1 || drifted+=("$f")
    done
    [[ ${#drifted[@]} -gt 0 ]] && echo "${drifted[*]}" || true
}

_zed_last_sync() {
    local ts_file="$DOTFILES_DIR/.zed-sync-ts"
    [[ -f "$ts_file" ]] || { echo "never"; return; }
    local ts now diff
    ts=$(date -d "$(cat "$ts_file")" +%s 2>/dev/null) || ts=$(stat -c '%Y' "$ts_file" 2>/dev/null)
    now=$(date +%s)
    diff=$(( now - ts ))
    if   (( diff < 60   )); then echo "just now"
    elif (( diff < 3600 )); then echo "$(( diff / 60 ))min ago"
    elif (( diff < 86400)); then echo "$(( diff / 3600 ))h ago"
    else                         echo "$(( diff / 86400 ))d ago"
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
    local last zed_sync drift version git_hash
    last=$(_last_update)
    zed_sync=$(_zed_last_sync)
    drift=$(_zed_drift)
    version="$(cat "$DOTFILES_DIR/VERSION" 2>/dev/null || echo "?")"
    git_hash="$(git -C "$DOTFILES_DIR" rev-parse --short HEAD 2>/dev/null || echo "?")"

    gum style --bold --foreground 220 "DOTFILES  v${version} (${git_hash})  ·  updated: ${last}"
    echo
    _badge "$zsh_st"  "zsh"     "$([[ $zsh_st  == ok ]] && echo linked   || echo "not linked")"
    _badge "$git_st"  "git"     "$([[ $git_st  == ok ]] && echo configured || echo "check gitconfig")"
    if [[ -n "$drift" ]]; then
        _badge "warn" "zed" "synced ${zed_sync} · Windows has local edits: ${drift}"
    else
        _badge "$zed_st" "zed" "$([[ $zed_st == ok ]] && echo "synced ${zed_sync}" || echo "not synced")"
    fi
    _badge "$sec_st"  "secrets" "$([[ $sec_st  == ok ]] && echo ok || { [[ $sec_st == warn ]] && echo "bad perms" || echo "missing"; })"
    _badge "$node_st" "node"    "$(command -v node >/dev/null 2>&1 && node --version 2>/dev/null || echo "not found")"
    echo
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    show_status
fi

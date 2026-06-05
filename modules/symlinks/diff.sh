#!/usr/bin/env bash
# Preview: would the symlinks module need to do anything?
set -uo pipefail
. "$DOTFILES_DIR/modules/_lib/log.sh"

# Hardcoded list mirrors scripts/install/symlinks.sh (kept in sync manually).
declare -A LINKS=(
    [".zshrc"]="$HOME/.zshrc"
    [".zshenv"]="$HOME/.zshenv"
    [".gitconfig"]="$HOME/.gitconfig"
    [".gitignore_global"]="$HOME/.gitignore_global"
    [".config/starship.toml"]="$HOME/.config/starship.toml"
    [".config/lazygit"]="$HOME/.config/lazygit"
    [".config/bat"]="$HOME/.config/bat"
    [".config/procs"]="$HOME/.config/procs"
    [".codex"]="$HOME/.codex"
)

printf "  %-32s %-12s %s\n" "TARGET" "STATE" "EXPECTED SOURCE"
printf "  %-32s %-12s %s\n" "------" "-----" "---------------"

local_status() {
    local src_rel="$1" target="$2"
    local src_abs="$DOTFILES_DIR/$src_rel"
    if [[ ! -e "$src_abs" ]]; then
        printf "%smissing-src%s" "$_C_RED" "$_C_RESET"; return
    fi
    if [[ -L "$target" ]]; then
        local rl
        rl="$(readlink -f "$target" 2>/dev/null || echo "")"
        if [[ "$rl" == "$src_abs" ]]; then
            printf "%sok%s" "$_C_GREEN" "$_C_RESET"
        else
            printf "%swrong-target%s" "$_C_YELLOW" "$_C_RESET"
        fi
    elif [[ -e "$target" ]]; then
        printf "%snot-a-link%s" "$_C_YELLOW" "$_C_RESET"
    else
        printf "%smissing%s" "$_C_DIM" "$_C_RESET"
    fi
}

for src_rel in "${!LINKS[@]}"; do
    target="${LINKS[$src_rel]}"
    state="$(local_status "$src_rel" "$target")"
    # Replace $HOME for readability (tilde in substitution gets expanded to $HOME, so build manually).
    if [[ "$target" == "$HOME"* ]]; then
        short_target="~${target#$HOME}"
    else
        short_target="$target"
    fi
    printf "  %-32s %s %s\n" "$short_target" "$state" "$src_rel"
done | sort -k1

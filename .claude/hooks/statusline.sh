#!/usr/bin/env bash
# Claude Code statusline — combined badge
# Output: [CAVEMAN] · dir · ⎇ branch

CAVEMAN_SCRIPT="$HOME/.claude/plugins/cache/caveman/caveman/ef6050c5e184/hooks/caveman-statusline.sh"

# Caveman badge
caveman_out=""
if [[ -f "$CAVEMAN_SCRIPT" ]]; then
    caveman_out="$(bash "$CAVEMAN_SCRIPT" 2>/dev/null)"
fi

# Current working directory (warm Nordic: #e76f51)
cwd_part=""
cwd_val="${PWD:-}"
if [[ -n "$cwd_val" ]]; then
    cwd_val="${cwd_val/#$HOME/\~}"
    # Keep last 2 segments (mirrors Starship truncation_length=2)
    cwd_val="$(printf '%s' "$cwd_val" | awk -F/ 'NF>2{print "…/" $(NF-1) "/" $NF} NF==2{print $1 "/" $2} NF<=1{print $0}')"
    cwd_part="$(printf ' \033[38;5;240m·\033[0m \033[38;2;231;111;81m%s\033[0m' "$cwd_val")"
fi

# Git branch (warm Nordic: #f4a261)
git_branch=""
if command -v git >/dev/null 2>&1; then
    branch="$(git branch --show-current 2>/dev/null)"
    if [[ -n "$branch" ]]; then
        git_branch="$(printf ' \033[38;5;240m·\033[0m \033[38;2;244;162;97m\xef\xa3\xa6 %s\033[0m' "$branch")"
    fi
fi

printf '%s%s%s' "${caveman_out}" "${cwd_part}" "${git_branch}"

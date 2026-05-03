#!/usr/bin/env bash
# Claude Code statusline — combined badge
# Output: [CAVEMAN] · dir · ⎇ branch · model

CAVEMAN_SCRIPT="$HOME/.claude/plugins/cache/caveman/caveman/ef6050c5e184/hooks/caveman-statusline.sh"

# Read JSON input from stdin (Claude Code passes session data)
input="$(cat)"

# Caveman badge (handles its own colors + savings suffix)
if [[ -f "$CAVEMAN_SCRIPT" ]]; then
    caveman_out="$(echo "$input" | bash "$CAVEMAN_SCRIPT" 2>/dev/null)"
fi

# Current working directory from JSON (warm Nordic: #e76f51)
cwd_part=""
if command -v jq >/dev/null 2>&1; then
    cwd_val="$(echo "$input" | jq -r '.workspace.current_dir // .cwd // empty' 2>/dev/null)"
    if [[ -n "$cwd_val" ]]; then
        # Shorten home directory to ~
        cwd_val="${cwd_val/#$HOME/\~}"
        # Keep only last 2 path segments (mirrors Starship truncation_length=2)
        cwd_val="$(echo "$cwd_val" | awk -F/ 'NF>2{print "…/" $(NF-1) "/" $NF} NF==2{print $1 "/" $2} NF<=1{print $0}')"
        cwd_part="$(printf ' \033[38;5;240m·\033[0m \033[38;2;231;111;81m%s\033[0m' "$cwd_val")"
    fi
fi

# Git branch — only if inside a git repo (warm Nordic: #f4a261)
git_branch=""
if command -v git >/dev/null 2>&1; then
    branch="$(git -C "${cwd_val:-$HOME}" branch --show-current 2>/dev/null)"
    [[ -z "$branch" ]] && branch="$(git branch --show-current 2>/dev/null)"
    if [[ -n "$branch" ]]; then
        git_branch="$(printf ' \033[38;5;240m·\033[0m \033[38;2;244;162;97m  %s\033[0m' "$branch")"
    fi
fi

# Model display name (dim muted blue: #6272a4)
model_part=""
if command -v jq >/dev/null 2>&1; then
    model_name="$(echo "$input" | jq -r '.model.display_name // empty' 2>/dev/null)"
    if [[ -n "$model_name" ]]; then
        model_part="$(printf ' \033[38;5;240m·\033[0m \033[38;2;98;114;164m%s\033[0m' "$model_name")"
    fi
fi

printf '%s%s%s%s' "${caveman_out:-}" "${cwd_part}" "${git_branch}" "${model_part}"

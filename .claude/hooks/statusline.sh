#!/usr/bin/env bash
# Claude Code statusline — combined badge
# Output: [CAVEMAN] · ⎇ branch

CAVEMAN_SCRIPT="$HOME/.claude/plugins/cache/caveman/caveman/ef6050c5e184/hooks/caveman-statusline.sh"

# Caveman badge (handles its own colors + savings suffix)
if [[ -f "$CAVEMAN_SCRIPT" ]]; then
    caveman_out="$(bash "$CAVEMAN_SCRIPT" 2>/dev/null)"
fi

# Git branch — only if inside a git repo
git_branch=""
if command -v git >/dev/null 2>&1; then
    branch="$(git branch --show-current 2>/dev/null)"
    if [[ -n "$branch" ]]; then
        # Dim separator + branch symbol + branch name
        git_branch="$(printf ' \033[38;5;240m·\033[0m \033[38;5;111m⎇ %s\033[0m' "$branch")"
    fi
fi

printf '%s%s' "${caveman_out:-}" "${git_branch}"

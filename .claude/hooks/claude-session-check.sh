#!/usr/bin/env bash
# Runs at every Claude Code session start (non-async).
# Output goes into Claude's context — Claude sees any warnings immediately.

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/.config/dotfiles}"
if [[ ! -d "$DOTFILES_DIR" ]]; then
    DOTFILES_DIR="$HOME/dotfiles"
fi

# Source secrets so we can check tokens
# shellcheck disable=SC1090
[[ -f "$HOME/.local-secrets" ]] && set -a && source "$HOME/.local-secrets" 2>/dev/null && set +a

issues=()

# Token check
if [[ -z "${GITHUB_PERSONAL_ACCESS_TOKEN:-}" ]]; then
    issues+=("GITHUB_PERSONAL_ACCESS_TOKEN mangler — tilføj til ~/.local-secrets")
fi

# Symlink checks
if [[ ! -L "$HOME/.claude/settings.json" ]]; then
    issues+=("~/.claude/settings.json er ikke et symlink — kør Update i dotfiles TUI")
fi
if [[ ! -f "$HOME/.claude/CLAUDE.md" ]]; then
    issues+=("~/.claude/CLAUDE.md mangler — kør Update i dotfiles TUI")
fi

# Hook executability
for hook in rtk-rewrite.sh entroly-start.sh claude-session-check.sh; do
    hpath="$HOME/.claude/hooks/$hook"
    if [[ -f "$hpath" && ! -x "$hpath" ]]; then
        issues+=("$hpath ikke eksekverbar — fix: chmod +x $hpath")
    fi
done

# RTK check
if ! command -v rtk >/dev/null 2>&1; then
    issues+=("rtk ikke installeret — se dotfiles README")
fi

if [[ ${#issues[@]} -gt 0 ]]; then
    echo ""
    echo "=== dotfiles config advarsler ==="
    for issue in "${issues[@]}"; do
        echo "  ⚠  $issue"
    done
    echo "  Fix: kør 'dotfiles' → Update"
    echo ""
fi

exit 0

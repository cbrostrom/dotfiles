# =============================================================================
# WORKFLOW PLUGINS — zsh-abbr + optional TUI aliases
# =============================================================================
# All hooks are guarded by `command -v` so missing tools never break startup.
# =============================================================================

# -----------------------------------------------------------------------------
# zsh-abbr — fish-like abbreviations (loaded via zinit if available)
# -----------------------------------------------------------------------------
if typeset -f zinit >/dev/null 2>&1; then
    zinit ice wait lucid
    zinit light olets/zsh-abbr
fi

# -----------------------------------------------------------------------------
# Optional TUI shortcuts (only define if binary exists)
# -----------------------------------------------------------------------------
command -v lazydocker >/dev/null 2>&1 && alias lzd='lazydocker'
command -v gh-dash    >/dev/null 2>&1 && alias ghd='gh dash'
command -v yazi       >/dev/null 2>&1 && alias y='yazi'

# Claude sync
alias claude-sync='bash ~/.config/dotfiles/scripts/claude/claude-sync.sh'

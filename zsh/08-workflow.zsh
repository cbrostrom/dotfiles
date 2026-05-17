# =============================================================================
# WORKFLOW PLUGINS — optional TUI aliases
# =============================================================================
# All hooks are guarded by `command -v` so missing tools never break startup.
# =============================================================================

# -----------------------------------------------------------------------------
# Optional TUI shortcuts (only define if binary exists)
# -----------------------------------------------------------------------------
command -v lazydocker >/dev/null 2>&1 && alias lzd='lazydocker'
command -v gh-dash    >/dev/null 2>&1 && alias ghd='gh dash'
command -v yazi       >/dev/null 2>&1 && alias y='yazi'

# Claude sync
alias claude-sync='bash ~/.config/dotfiles/scripts/claude/claude-sync.sh'

# Kill zsh quote-line / quote-region — Esc-' wraps whole line in single quotes,
# clashes with Danish layout where Option+key produces @ ~ etc and Option-leakage
# sends Esc-prefix into ZLE. Never used these widgets.
bindkey -r "^['" 2>/dev/null
bindkey -r "^[\"" 2>/dev/null

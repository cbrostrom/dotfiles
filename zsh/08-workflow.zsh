# =============================================================================
# WORKFLOW PLUGINS — atuin, mise, direnv, carapace, zsh-abbr
# =============================================================================
# All hooks are guarded by `command -v` so missing tools never break startup.
# Heavy `eval` calls are routed through cache_eval (defined in lib/platform.sh).
# =============================================================================

# Fallback if cache_eval is not loaded (e.g. someone sources this in isolation)
if ! typeset -f cache_eval >/dev/null 2>&1; then
    cache_eval() { eval "$2"; }
fi

# -----------------------------------------------------------------------------
# mise (https://mise.jdx.dev) — replaces fnm + adds python/ruby/etc.
# Coexists with fnm during migration.
# -----------------------------------------------------------------------------
if command -v mise >/dev/null 2>&1; then
    cache_eval mise "mise activate zsh"
fi

# -----------------------------------------------------------------------------
# direnv — per-project .envrc auto-load
# -----------------------------------------------------------------------------
if command -v direnv >/dev/null 2>&1; then
    cache_eval direnv "direnv hook zsh"
fi

# -----------------------------------------------------------------------------
# atuin — encrypted shell history sync
# Server: superbro VPS via Tailscale (http://superbro:8888)
# -----------------------------------------------------------------------------
if command -v atuin >/dev/null 2>&1; then
    # Disable up-arrow rebind if user prefers default (set in ~/.local-config)
    if [[ "${ATUIN_NOBIND:-}" != "true" ]]; then
        eval "$(atuin init zsh)"
    else
        eval "$(atuin init zsh --disable-up-arrow)"
    fi
fi

# -----------------------------------------------------------------------------
# carapace — multi-shell completion engine
# -----------------------------------------------------------------------------
if command -v carapace >/dev/null 2>&1; then
    export CARAPACE_BRIDGES='zsh,fish,bash'
    zstyle ':completion:*' format $'\e[2;37mCompleting %d\e[m'
    cache_eval carapace "carapace _carapace zsh"
fi

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

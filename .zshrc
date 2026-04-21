# =============================================================================
# MODULAR ZSH CONFIGURATION (Performance Optimized)
# =============================================================================
# This is a clean, modular zsh configuration that loads separate modules
# for better organization and maintainability.
#
# Structure:
#   00-performance.zsh  - Caching & lazy loading for fast startup (~50-75% faster)
#   01-environment.zsh  - OS detection, terminal setup, PATH, environment vars
#   02-plugins.zsh      - zinit, FZF, completions, zoxide, starship, fnm
#   03-aliases.zsh      - Modern tool replacements and shortcuts
#   04-functions.zsh    - Custom functions and utilities
#   05-integrations.zsh - Editor integrations (Cursor, VS Code)
#
# Performance Features:
#   - Homebrew shellenv caching (saves ~50-100ms)
#   - Init command caching for starship, zoxide, fnm (saves ~150-300ms)
#   - Google Cloud SDK lazy loading (saves ~200-500ms)
#   - Optimized compinit (no duplicates)
#
# Cache location: ~/.cache/zsh/
# Clear cache: rm -rf ~/.cache/zsh/ && exec zsh
#
# All modules are stored in: ~/dotfiles/zsh/
# =============================================================================

# Determine the dotfiles directory
# This works whether .zshrc is sourced directly or via symlink
ZSHRC_PATH="${(%):-%N}"

# If ~/.zshrc is a symlink, resolve it
if [[ -L "$HOME/.zshrc" ]]; then
    ZSHRC_PATH="$(readlink -f "$HOME/.zshrc")"
fi

# Get the directory containing .zshrc
DOTFILES_DIR="$(dirname "$ZSHRC_PATH")"

# Ensure DOTFILES_DIR is absolute
if [[ "$DOTFILES_DIR" != /* ]]; then
    DOTFILES_DIR="$HOME/$DOTFILES_DIR"
fi

# If we ended up in home directory, try common locations
if [[ "$DOTFILES_DIR" == "$HOME" ]]; then
    if [[ -d "$HOME/.config/dotfiles" ]]; then
        DOTFILES_DIR="$HOME/.config/dotfiles"
    elif [[ -d "$HOME/dotfiles" ]]; then
        DOTFILES_DIR="$HOME/dotfiles"
    fi
fi

ZSH_MODULES_DIR="$DOTFILES_DIR/zsh"

# =============================================================================
# LOAD MODULES
# =============================================================================
# Load each module in order
# Modules are loaded only if they exist to prevent errors

if [[ -d "$ZSH_MODULES_DIR" ]]; then
    # 00 - Performance optimizations (caching, lazy loading)
    [[ -f "$ZSH_MODULES_DIR/00-performance.zsh" ]] && source "$ZSH_MODULES_DIR/00-performance.zsh"
    
    # 01 - Environment (OS detection, PATH, terminal)
    [[ -f "$ZSH_MODULES_DIR/01-environment.zsh" ]] && source "$ZSH_MODULES_DIR/01-environment.zsh"
    
    # 02 - Plugins (zinit, FZF, completions, zoxide, starship, fnm)
    [[ -f "$ZSH_MODULES_DIR/02-plugins.zsh" ]] && source "$ZSH_MODULES_DIR/02-plugins.zsh"
    
    # 03 - Aliases (modern tool replacements)
    [[ -f "$ZSH_MODULES_DIR/03-aliases.zsh" ]] && source "$ZSH_MODULES_DIR/03-aliases.zsh"
    
    # 04 - Functions (custom utilities)
    [[ -f "$ZSH_MODULES_DIR/04-functions.zsh" ]] && source "$ZSH_MODULES_DIR/04-functions.zsh"
    
    # 05 - Integrations (editor integrations)
    [[ -f "$ZSH_MODULES_DIR/05-integrations.zsh" ]] && source "$ZSH_MODULES_DIR/05-integrations.zsh"

    # 06 - Auto-update notification (background fetch + tiered notify)
    [[ -f "$ZSH_MODULES_DIR/06-autoupdate.zsh" ]] && source "$ZSH_MODULES_DIR/06-autoupdate.zsh"
else
    echo "Warning: ZSH modules directory not found at $ZSH_MODULES_DIR"
    echo "Falling back to basic configuration"
    
    # Minimal fallback configuration
    export PATH="$HOME/bin:$HOME/.local/bin:$PATH"
    
    # Load starship if available
    if command -v starship &>/dev/null; then
        eval "$(starship init zsh)"
    fi
fi

# =============================================================================
# MACHINE-SPECIFIC CONFIGURATION (Optional)
# =============================================================================
# Load machine-specific configuration if it exists
# This file is not tracked in git and can contain local customizations
if [[ -f "$HOME/.zshrc.local" ]]; then
    source "$HOME/.zshrc.local"
fi

# =============================================================================
# PERFORMANCE PROFILING (Optional)
# =============================================================================
# Uncomment to enable zsh startup profiling
# To use: Add 'zmodload zsh/zprof' to the top of this file
# Then run 'zprof' after shell startup to see timing report
# [[ -n "$ZPROF" ]] && zprof


# fnm (Linux)
FNM_PATH="/home/christian/.local/share/fnm"
if [ -d "$FNM_PATH" ]; then
  export PATH="$FNM_PATH:$PATH"
  eval "`fnm env`"
fi

# bun completions
[ -s "/home/christian/.bun/_bun" ] && source "/home/christian/.bun/_bun"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

# Added by LM Studio CLI (lms)
export PATH="$PATH:/Users/Christian.Brostrom/.lmstudio/bin"
# End of LM Studio CLI section


# lean-ctx shell hook — transparent CLI compression (90+ patterns)
_lean_ctx_cmds=(git cargo docker docker-compose kubectl gh pip pip3 ruff go golangci-lint eslint prettier tsc ls find grep curl wget)

lean-ctx-on() {
    for _lc_cmd in "${_lean_ctx_cmds[@]}"; do
        # shellcheck disable=SC2139
        alias "$_lc_cmd"='/Users/Christian.Brostrom/.cargo/bin/lean-ctx -c '"$_lc_cmd"
    done
    alias k='/Users/Christian.Brostrom/.cargo/bin/lean-ctx -c kubectl'
    export LEAN_CTX_ENABLED=1
    echo "lean-ctx: ON"
}

lean-ctx-off() {
    for _lc_cmd in "${_lean_ctx_cmds[@]}"; do
        unalias "$_lc_cmd" 2>/dev/null || true
    done
    unalias k 2>/dev/null || true
    unset LEAN_CTX_ENABLED
    echo "lean-ctx: OFF"
}

lean-ctx-status() {
    if [ -n "${LEAN_CTX_ENABLED:-}" ]; then
        echo "lean-ctx: ON"
    else
        echo "lean-ctx: OFF"
    fi
}

if [ -z "${LEAN_CTX_ACTIVE:-}" ] \
   && { [ "${LEAN_CTX_ENABLED:-0}" != "0" ] \
        || [ -n "${CURSOR_AGENT:-}" ] \
        || [ -n "${CURSOR_TRACE_ID:-}" ] \
        || [ -n "${CLAUDECODE:-}" ] \
        || [ -n "${CODEX_CLI:-}" ] \
        || [ -n "${AI_AGENT:-}" ]; }; then
    lean-ctx-on >/dev/null
fi
# lean-ctx shell hook — end

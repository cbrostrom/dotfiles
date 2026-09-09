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

# Load shared platform helpers (is_macos, is_linux, has, cache_eval, profile, …)
[[ -f "$ZSH_MODULES_DIR/lib/platform.sh" ]] && source "$ZSH_MODULES_DIR/lib/platform.sh"

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

    # 08 - Workflow plugins (zsh-abbr + optional TUI aliases) — guarded
    [[ -f "$ZSH_MODULES_DIR/08-workflow.zsh" ]] && source "$ZSH_MODULES_DIR/08-workflow.zsh"

    # 09 - Herdr agent state integration
    [[ -f "$ZSH_MODULES_DIR/09-herdr.zsh" ]] && source "$ZSH_MODULES_DIR/09-herdr.zsh"

    # 10 - Cmux orchestration helpers
    [[ -f "$ZSH_MODULES_DIR/09-cmux.zsh" ]] && source "$ZSH_MODULES_DIR/09-cmux.zsh"

    # Per-host overrides BEFORE Zellij auto-attach so a host can opt out
    [[ -f "$HOME/.zshrc.local" ]] && source "$HOME/.zshrc.local"
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

# Note: ~/.zshrc.local is sourced inside the modules block above,
# so host-specific overrides take effect before any auto-attach logic.

# =============================================================================
# PERFORMANCE PROFILING (Optional)
# =============================================================================
# Uncomment to enable zsh startup profiling
# To use: Add 'zmodload zsh/zprof' to the top of this file
# Then run 'zprof' after shell startup to see timing report
# [[ -n "$ZPROF" ]] && zprof



unset MAILCHECK

# opencode (Linux only)
[[ -d /home/christian/.opencode/bin ]] && export PATH=/home/christian/.opencode/bin:$PATH

# OBSIDIAN_API_KEY and other rbw secrets: modules/rbw/env-secrets.zsh (.zshenv)
export PATH="/usr/local/go/bin:$HOME/go/bin:$PATH"

# Homebrew (linux)
if [[ -x /home/linuxbrew/.linuxbrew/bin/brew ]]; then
  eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv zsh)"
fi

# fnm
FNM_PATH="/home/christian/.local/share/fnm"
if [ -d "$FNM_PATH" ]; then
  export PATH="$FNM_PATH:$PATH"
  eval "$(fnm env --shell zsh)"
fi

# Added by codebase-memory-mcp install
export PATH="/Users/Christian.Brostrom/.local/bin:$PATH"
# >>> llmtrim >>>
# Self-healing, fail-open llmtrim proxy configuration.

_llmtrim_clear_env() {
    unset HTTPS_PROXY HTTP_PROXY ALL_PROXY
    unset https_proxy http_proxy all_proxy
    unset NODE_EXTRA_CA_CERTS SSL_CERT_FILE CURL_CA_BUNDLE NODE_USE_ENV_PROXY
    unset NO_PROXY no_proxy
}

_llmtrim_enable_env() {
    export HTTPS_PROXY='http://127.0.0.1:43117'
    export HTTP_PROXY='http://127.0.0.1:43117'
    # Cursor control plane bypasses MITM (vendor gateway); LLM provider hosts stay proxied.
    export NO_PROXY='localhost,127.0.0.1,::1,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,169.254.0.0/16,fd00::/8,*.local,*.cursor.sh,*.cursor.com,cursor.sh,cursor.com,api2.cursor.sh'
    export no_proxy='localhost,127.0.0.1,::1,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,169.254.0.0/16,fd00::/8,*.local,*.cursor.sh,*.cursor.com,cursor.sh,cursor.com,api2.cursor.sh'
    export NODE_USE_ENV_PROXY=1
    export NODE_EXTRA_CA_CERTS="$HOME/.llmtrim/ca.pem"
    export SSL_CERT_FILE="$HOME/.llmtrim/ca-bundle.pem"
    export CURL_CA_BUNDLE="$HOME/.llmtrim/ca-bundle.pem"
}

# Remove inherited or stale llmtrim settings first.
_llmtrim_clear_env

if command -v llmtrim >/dev/null 2>&1; then
    if ! llmtrim _alive >/dev/null 2>&1; then
        llmtrim start >/dev/null 2>&1

        # Poll briefly instead of using a long fixed delay.
        for _llmtrim_attempt in 1 2 3 4; do
            llmtrim _alive >/dev/null 2>&1 && break
            sleep 0.25
        done
        unset _llmtrim_attempt
    fi

    if llmtrim _alive >/dev/null 2>&1; then
        _llmtrim_enable_env
    else
        # Fail open: leave proxy and custom CA variables unset.
        _llmtrim_clear_env
    fi
fi

unset -f _llmtrim_clear_env _llmtrim_enable_env
# <<< llmtrim <<<

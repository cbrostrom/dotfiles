# =============================================================================
# PERFORMANCE OPTIMIZATIONS
# =============================================================================
# This file contains caching and optimization strategies to speed up zsh startup
# Load this BEFORE other modules for maximum benefit

# =============================================================================
# HOMEBREW SHELLENV CACHING (macOS)
# =============================================================================
# Cache Homebrew's shellenv output to avoid running it every time (~50-100ms saved)
if [[ "$OSTYPE" == "Darwin" ]]; then
    BREW_CACHE_FILE="$HOME/.cache/zsh/brew-shellenv.zsh"
    BREW_CACHE_VALID=86400  # 24 hours in seconds
    
    # Create cache directory if it doesn't exist
    mkdir -p "$(dirname "$BREW_CACHE_FILE")"
    
    # Function to generate brew shellenv cache
    _generate_brew_cache() {
        local brew_path=""
        if [[ -f "/opt/homebrew/bin/brew" ]]; then
            brew_path="/opt/homebrew/bin/brew"
        elif [[ -f "/usr/local/bin/brew" ]]; then
            brew_path="/usr/local/bin/brew"
        fi
        
        if [[ -n "$brew_path" ]]; then
            "$brew_path" shellenv > "$BREW_CACHE_FILE"
        fi
    }
    
    # Check if cache exists and is fresh
    if [[ ! -f "$BREW_CACHE_FILE" ]] || [[ $(find "$BREW_CACHE_FILE" -mtime +1 2>/dev/null) ]]; then
        # Cache is old or doesn't exist, regenerate
        _generate_brew_cache
    fi
    
    # Source cached shellenv (much faster than running brew shellenv)
    if [[ -f "$BREW_CACHE_FILE" ]]; then
        source "$BREW_CACHE_FILE"
    fi
    
    unset -f _generate_brew_cache
fi

# =============================================================================
# INIT COMMAND CACHING
# =============================================================================
# Cache expensive eval commands for tools like starship, zoxide, fnm
# This can save 100-300ms on startup

INIT_CACHE_DIR="$HOME/.cache/zsh/init"
mkdir -p "$INIT_CACHE_DIR"

# Function to cache and source init commands
_cached_eval() {
    local cache_name="$1"
    local init_command="$2"
    local cache_file="$INIT_CACHE_DIR/${cache_name}.zsh"
    local cache_valid=86400  # 24 hours
    
    # Check if cache exists and is fresh
    if [[ ! -f "$cache_file" ]] || [[ $(find "$cache_file" -mtime +1 2>/dev/null) ]]; then
        # Regenerate cache
        eval "$init_command" > "$cache_file" 2>/dev/null
    fi
    
    # Source cached output
    if [[ -f "$cache_file" ]]; then
        source "$cache_file"
    else
        # Fallback: run command directly if cache failed
        eval "$init_command"
    fi
}

# Export for use in other modules
export -f _cached_eval 2>/dev/null || true

# =============================================================================
# BINARY PATH CACHING (used by other modules)
# =============================================================================
# Cache lookups so other modules don't re-resolve git/timeout each invocation
export DOTFILES_GIT_BIN="${DOTFILES_GIT_BIN:-$(command -v /opt/homebrew/bin/git 2>/dev/null || command -v git)}"
export DOTFILES_TIMEOUT_BIN="${DOTFILES_TIMEOUT_BIN:-$(command -v gtimeout 2>/dev/null || command -v timeout 2>/dev/null)}"

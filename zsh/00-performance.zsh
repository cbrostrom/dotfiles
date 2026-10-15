# =============================================================================
# PERFORMANCE OPTIMIZATIONS
# =============================================================================
# This file contains caching and optimization strategies to speed up zsh startup
# Load this BEFORE other modules for maximum benefit
#
# Rule for this file: no forks on the startup path. Age checks use the zsh glob
# qualifier (Nmh-24) ("exists and modified less than 24h ago") instead of
# `find -mtime`, and binaries are resolved through $commands instead of `$(…)`.

# True when $1 exists and was modified less than 24h ago. Array assignment is
# the only place the qualifier is expanded; inside [[ ]] it would be literal.
_zsh_fresh24() {
    local -a m
    m=( $1(Nmh-24) )
    (( $#m ))
}

# =============================================================================
# HOMEBREW SHELLENV CACHING (macOS)
# =============================================================================
# Cache Homebrew's shellenv output to avoid running it every time (~50-100ms saved)
# $OSTYPE is e.g. darwin25.4.0, never the bare "Darwin" uname gives.
if [[ "$OSTYPE" == darwin* ]]; then
    BREW_CACHE_FILE="$HOME/.cache/zsh/brew-shellenv.zsh"

    # Create cache directory if it doesn't exist
    [[ -d "${BREW_CACHE_FILE:h}" ]] || mkdir -p "${BREW_CACHE_FILE:h}"

    # Function to generate brew shellenv cache
    _generate_brew_cache() {
        local brew_path=""
        if [[ -x "/opt/homebrew/bin/brew" ]]; then
            brew_path="/opt/homebrew/bin/brew"
        elif [[ -x "/usr/local/bin/brew" ]]; then
            brew_path="/usr/local/bin/brew"
        fi

        if [[ -n "$brew_path" ]]; then
            "$brew_path" shellenv > "$BREW_CACHE_FILE"
            zcompile -R "$BREW_CACHE_FILE" 2>/dev/null
        fi
    }

    # Regenerate when the cache is missing or older than 24h
    _zsh_fresh24 "$BREW_CACHE_FILE" || _generate_brew_cache

    # Source cached shellenv (much faster than running brew shellenv)
    if [[ -f "$BREW_CACHE_FILE" ]]; then
        source "$BREW_CACHE_FILE"
    fi

    unset -f _generate_brew_cache 2>/dev/null
fi

# =============================================================================
# INIT COMMAND CACHING
# =============================================================================
# Cache expensive eval commands for tools like starship and zoxide.
# Not for fnm: its env output contains a per-shell multishell path.

INIT_CACHE_DIR="$HOME/.cache/zsh/init"
[[ -d "$INIT_CACHE_DIR" ]] || mkdir -p "$INIT_CACHE_DIR"

# Function to cache and source init commands
_cached_eval() {
    local cache_name="$1"
    local init_command="$2"
    local cache_file="$INIT_CACHE_DIR/${cache_name}.zsh"

    # Regenerate when the cache is missing or older than 24h
    if ! _zsh_fresh24 "$cache_file"; then
        eval "$init_command" > "$cache_file" 2>/dev/null
        zcompile -R "$cache_file" 2>/dev/null
    fi

    # Source cached output (zsh auto-picks .zwc if newer)
    if [[ -f "$cache_file" ]]; then
        source "$cache_file"
    else
        # Fallback: run command directly if cache failed
        eval "$init_command"
    fi
}

# =============================================================================
# ZWC BYTECODE — auto-recompile stale .zwc for rc files & modules
# =============================================================================
# zsh's `source` transparently picks the .zwc bytecode if it exists and is
# newer than the .zsh source. Compile synchronously: a backgrounded (&!)
# job gets killed by fast shell exits (~180ms) before it ever finishes.
# Only stale files are compiled (~5ms each), so this is near-free.
_zsh_recompile_if_stale() {
    local f repo="${DOTFILES_DIR:-$HOME/dotfiles}"
    for f in \
        ~/.zshenv ~/.zshrc \
        "$repo/stow/zsh/.zshenv" "$repo/stow/zsh/.zshrc" \
        "$repo"/zsh/*.zsh(N)
    do
        [[ -f "$f" ]] || continue
        if [[ ! -f "${f}.zwc" ]] || [[ "$f" -nt "${f}.zwc" ]]; then
            zcompile -R "$f" 2>/dev/null
        fi
    done
}
_zsh_recompile_if_stale

# Note: _cached_eval is auto-available in subsequent sourced modules within
# the same shell — no `export -f` needed (zsh doesn't support it anyway).

# =============================================================================
# BINARY PATH CACHING (used by other modules)
# =============================================================================
# Cache lookups so other modules don't re-resolve git/timeout each invocation.
# $commands is zsh's hash table of PATH lookups: no subshell needed.
if [[ -z "$DOTFILES_GIT_BIN" ]]; then
    if [[ -x /opt/homebrew/bin/git ]]; then
        DOTFILES_GIT_BIN=/opt/homebrew/bin/git
    else
        DOTFILES_GIT_BIN="${commands[git]:-git}"
    fi
fi
export DOTFILES_GIT_BIN
export DOTFILES_TIMEOUT_BIN="${DOTFILES_TIMEOUT_BIN:-${commands[gtimeout]:-${commands[timeout]:-}}}"

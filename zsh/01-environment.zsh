# =============================================================================
# ENVIRONMENT CONFIGURATION
# =============================================================================
# OS detection, terminal setup, and environment variables

# =============================================================================
# OS DETECTION
# =============================================================================
OS_TYPE="$(uname -s)"
IS_MACOS=false
IS_LINUX=false
IS_WSL=false

if [[ "$OS_TYPE" == "Darwin" ]]; then
    IS_MACOS=true
elif [[ "$OS_TYPE" == "Linux" ]]; then
    IS_LINUX=true
    if grep -q Microsoft /proc/version 2>/dev/null; then
        IS_WSL=true
    fi
fi

# =============================================================================
# TERMINAL CONFIGURATION
# =============================================================================
# Set appropriate terminal type based on OS
if $IS_MACOS; then
    # On macOS, allow ghostty or other macOS terminals
    if [[ -z "$TERM" ]] || [[ "$TERM" == "dumb" ]]; then
        export TERM="xterm-256color"
    fi
else
    # On Linux/Debian, always use xterm-256color for compatibility
    export TERM="xterm-256color"
fi

# =============================================================================
# SSH AGENT AUTO-START
# =============================================================================
# Automatically start ssh-agent and load all SSH keys
# On macOS, use built-in ssh-agent with Keychain integration instead
if ! $IS_MACOS; then
    for _df in "$HOME/.config/dotfiles" "$HOME/dotfiles"; do
        [[ -f "$_df/scripts/system/ssh-agent-setup.sh" ]] && source "$_df/scripts/system/ssh-agent-setup.sh" && break
    done
fi

# =============================================================================
# PATH SETUP
# =============================================================================
# Basic PATH setup - include ~/bin and ~/.local/bin
export PATH="$HOME/bin:$HOME/.local/bin:$PATH"
export GOPATH="$HOME/go"
export PATH="$GOPATH/bin:$PATH"

# =============================================================================
# EDITOR CONFIGURATION
# =============================================================================
# Zed primary, micro fallback (micro handles terminal-only contexts like git rebase)
if command -v zed >/dev/null 2>&1; then
    export EDITOR="zed --wait"
    export VISUAL="zed --wait"
    export GIT_EDITOR="zed --wait"
    export SUDO_EDITOR="micro"  # sudo keeps terminal editor
elif command -v micro >/dev/null 2>&1; then
    export EDITOR="micro"
    export VISUAL="micro"
    export SUDO_EDITOR="micro"
fi

# Node/Web development environment
export NODE_OPTIONS="--max-old-space-size=8192"

# npm configuration (no pnpm)
export NPM_CONFIG_FUND=false
export NPM_CONFIG_AUDIT=false

# =============================================================================
# HOMEBREW SETUP
# =============================================================================
# macOS brew shellenv is cached and sourced in 00-performance.zsh.
# Only Linux (homelab/linuxbrew) is handled here — small enough not to need cache.
if $IS_LINUX; then
    if [[ -x "/home/linuxbrew/.linuxbrew/bin/brew" ]]; then
        eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
    elif command -v brew >/dev/null 2>&1; then
        eval "$(brew shellenv)"
    fi
fi

# Skip the implicit `brew update` before every install — saves 20-60s per
# command. Schedule explicit `brew update` via cron / launchd if desired.
export HOMEBREW_NO_AUTO_UPDATE=1
# Skip post-install cleanup of old versions. Run `brew cleanup` weekly.
export HOMEBREW_NO_INSTALL_CLEANUP=1
# Let bare `brew bundle` / `brew bundle check` work from any cwd.
export HOMEBREW_BUNDLE_FILE="$HOME/dotfiles/Brewfile"

# =============================================================================
# NODE / BUN / FNM (cross-platform, $HOME-based)
# =============================================================================
# fnm: prefer XDG dir, fall back to default install location
if [[ -d "$HOME/.local/share/fnm" ]]; then
    export PATH="$HOME/.local/share/fnm:$PATH"
elif [[ -d "$HOME/.fnm" ]]; then
    export PATH="$HOME/.fnm:$PATH"
fi

# Bun
if [[ -d "$HOME/.bun" ]]; then
    export BUN_INSTALL="$HOME/.bun"
    export PATH="$BUN_INSTALL/bin:$PATH"
    [[ -s "$HOME/.bun/_bun" ]] && source "$HOME/.bun/_bun"
fi

# =============================================================================
# LM STUDIO (mac only — desktop GUI app)
# =============================================================================
if $IS_MACOS && [[ -d "$HOME/.lmstudio/bin" ]]; then
    export PATH="$PATH:$HOME/.lmstudio/bin"
fi

# =============================================================================
# OLLAMA
# =============================================================================
# Unload models after 5 minutes of inactivity to free unified memory
export OLLAMA_KEEP_ALIVE=5m

# =============================================================================
# LOCAL SECRETS (Not tracked in git)
# =============================================================================
# Store sensitive tokens and API keys in ~/.local-secrets
# This file is NOT tracked in git - add it to .gitignore
if [[ -f "$HOME/.local-secrets" ]]; then
    set -a
    source "$HOME/.local-secrets"
    set +a
fi

# =============================================================================
# ZSH HISTORY CONFIGURATION
# =============================================================================
# Better history management with timestamps and deduplication
HISTFILE=~/.zsh_history
HISTSIZE=50000
SAVEHIST=50000
setopt EXTENDED_HISTORY          # Write timestamp to history file
setopt INC_APPEND_HISTORY        # Append immediately, not on shell exit
setopt SHARE_HISTORY             # Share history between all sessions
setopt HIST_IGNORE_DUPS          # Don't record duplicate entries
setopt HIST_IGNORE_SPACE         # Don't record commands starting with space
setopt HIST_REDUCE_BLANKS        # Remove unnecessary blanks
setopt HIST_VERIFY               # Show command with history expansion before running

# =============================================================================
# GOOGLE CLOUD SDK (Lazy Loaded for Performance)
# =============================================================================
# Lazy load Google Cloud SDK to improve startup time (~200-500ms saved)
# SDK will be loaded automatically when you first use 'gcloud' command
if [ -f '/opt/homebrew/share/google-cloud-sdk/path.zsh.inc' ]; then
    # Add gcloud to PATH without loading completions
    export PATH="/opt/homebrew/share/google-cloud-sdk/bin:$PATH"

    # Lazy load gcloud completions and full environment
    gcloud() {
        # Remove this function so it doesn't get called again
        unfunction gcloud

        # Load the full Google Cloud SDK
        if [ -f '/opt/homebrew/share/google-cloud-sdk/path.zsh.inc' ]; then
            . '/opt/homebrew/share/google-cloud-sdk/path.zsh.inc'
        fi

        # Load completions
        if [ -f '/opt/homebrew/share/google-cloud-sdk/completion.zsh.inc' ]; then
            . '/opt/homebrew/share/google-cloud-sdk/completion.zsh.inc'
        fi

        # Now run the actual gcloud command
        command gcloud "$@"
    }
fi

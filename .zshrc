# Detect OS
OS_TYPE="$(uname -s)"
IS_MACOS=false
IS_LINUX=false
IS_WSL=false
if [[ "$OS_TYPE" == "Darwin" ]]; then
    IS_MACOS=true
elif [[ "$OS_TYPE" == "Linux" ]]; then
    IS_LINUX=true
    # Check if running in WSL
    if grep -q Microsoft /proc/version 2>/dev/null; then
        IS_WSL=true
    fi
fi

# Suppress function display on startup for cleaner output
setopt NO_FUNCTION_ARGZERO

# Homebrew setup (macOS only) - check multiple possible locations
if $IS_MACOS; then
    if [[ -f "/opt/homebrew/bin/brew" ]]; then
        eval "$('/opt/homebrew/bin/brew' shellenv)"
    elif [[ -f "/usr/local/bin/brew" ]]; then
        eval "$('/usr/local/bin/brew' shellenv)"
    fi
fi

# PATH setup with deduplication
export GOPATH="$HOME/go"
typeset -U path
if $IS_MACOS; then
    path=("$HOME/.local/bin" "$GOPATH/bin" $path)
else
    path=("$HOME/.local/bin" "$GOPATH/bin" $path)
fi

# Node/Web development environment
export NODE_OPTIONS="--max-old-space-size=8192"
# Cross-platform pnpm home
if $IS_MACOS; then
    export PNPM_HOME="$HOME/Library/pnpm"
else
    export PNPM_HOME="$HOME/.local/share/pnpm"
fi

# Set the directory we want to store zinit and plugins
ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"

# Install zinit if it doesn't exist
if [ ! -d "$ZINIT_HOME" ]; then
    echo "Installing zinit..."
    mkdir -p "$(dirname $ZINIT_HOME)"
    git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
fi

# Source zinit if it exists
if [[ -f "${ZINIT_HOME}/zinit.zsh" ]]; then
    source "${ZINIT_HOME}/zinit.zsh"
else
    echo "Warning: zinit not found. Some features may not work."
fi

# Zoxide (better cd) - source if available
if command -v zoxide >/dev/null 2>&1; then
    eval "$(zoxide init --cmd cd zsh)"
fi

# Starship prompt (modern, fast) - replace oh-my-posh
if command -v starship &>/dev/null; then
    eval "$(starship init zsh)"
elif $IS_MACOS && command -v oh-my-posh &>/dev/null; then
    # Fallback to oh-my-posh on macOS
    eval "$(oh-my-posh init zsh --config https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/amro.omp.json)"
fi

# Direnv for project-specific env vars
if command -v direnv &>/dev/null; then
    eval "$(direnv hook zsh)"
fi

# Source organized configuration files (with error handling and timeouts)
if [[ -f "$HOME/.config/zsh/env" ]]; then
    source "$HOME/.config/zsh/env"
else
    echo "Warning: $HOME/.config/zsh/env not found"
fi

if [[ -f "$HOME/.config/zsh/plugins" ]]; then
    source "$HOME/.config/zsh/plugins"
else
    echo "Warning: $HOME/.config/zsh/plugins not found"
fi

if [[ -f "$HOME/.config/zsh/aliases" ]]; then
    source "$HOME/.config/zsh/aliases"
else
    echo "Warning: $HOME/.config/zsh/aliases not found"
fi

# Source functions quietly (no output)
if [[ -f "$HOME/.config/zsh/functions" ]]; then
    source "$HOME/.config/zsh/functions" >/dev/null 2>&1
fi

# Completions (optimized with timeout protection)
autoload -Uz compinit
compinit -C

# Only replay completions if zinit is available and not in WSL (to prevent freezing)
if command -v zinit &>/dev/null && ! $IS_WSL; then
    zinit cdreplay -q
fi

# History (optimized for web dev workflow)
HISTSIZE=10000
HISTFILE=~/.zsh_history
SAVEHIST=$HISTSIZE
HISTDUP=erase
setopt appendhistory sharehistory hist_ignore_space hist_ignore_all_dups hist_save_no_dups hist_ignore_dups hist_find_no_dups hist_reduce_blanks

# Smart history search
autoload -U up-line-or-beginning-search down-line-or-beginning-search
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search
bindkey "^[[A" up-line-or-beginning-search
bindkey "^[[B" down-line-or-beginning-search

# FZF keybindings for better fuzzy finding
if command -v fzf &>/dev/null; then
    # Ctrl+R for history search
    bindkey '^R' fzf-history-widget
    # Ctrl+T for file search
    bindkey '^T' fzf-file-widget
    # Alt+C for directory search
    bindkey '^[c' fzf-cd-widget
fi

# Completion styling with fzf-tab (only if zinit is available and not in WSL)
if command -v zinit &>/dev/null && ! $IS_WSL; then
    zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'
    zstyle ':completion:*' menu no
    zstyle ':fzf-tab:complete:cd:*' fzf-preview 'lsd --group-dirs first --color=always $realpath 2>/dev/null || ls --color $realpath'
    zstyle ':fzf-tab:complete:__zoxide_z:*' fzf-preview 'lsd --group-dirs first --color=always $realpath 2>/dev/null || ls --color $realpath'
    zstyle ':fzf-tab:complete:(kill|ps):argument-rest' fzf-preview 'procs --pid=$word -o cmd --no-headers -w -w'
    zstyle ':fzf-tab:complete:npm:*' fzf-preview 'cat package.json 2>/dev/null | jq .scripts 2>/dev/null || echo "No package.json found"'
fi

# Note: Dotfiles management functions are now defined in ~/.config/zsh/aliases
# and are available as: dotfiles, dotfiles-version, install-tools

dotfiles-version() {
    local version_path=""
    if [[ -f "$HOME/dotfiles/scripts/version.sh" ]]; then
        version_path="$HOME/dotfiles/scripts/version.sh"
    elif [[ -f "$HOME/.dotfiles/scripts/version.sh" ]]; then
        version_path="$HOME/.dotfiles/scripts/version.sh"
    else
        echo "Error: version.sh not found"
        return 1
    fi
    "$version_path" "$@"
}

install-tools() {
    local tools_path=""
    if [[ -f "$HOME/dotfiles/scripts/install-tools.sh" ]]; then
        tools_path="$HOME/dotfiles/scripts/install-tools.sh"
    elif [[ -f "$HOME/.dotfiles/scripts/install-tools.sh" ]]; then
        tools_path="$HOME/.dotfiles/scripts/install-tools.sh"
    else
        echo "Error: install-tools.sh not found"
        return 1
    fi
    "$tools_path" "$@"
}

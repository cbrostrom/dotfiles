# Detect OS
OS_TYPE="$(uname -s)"
IS_MACOS=false
IS_LINUX=false
if [[ "$OS_TYPE" == "Darwin" ]]; then
    IS_MACOS=true
elif [[ "$OS_TYPE" == "Linux" ]]; then
    IS_LINUX=true
fi

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
if [ ! -d "$ZINIT_HOME" ]; then
    mkdir -p "$(dirname $ZINIT_HOME)"
    git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
fi

source "${ZINIT_HOME}/zinit.zsh"

# Zoxide (better cd) - source if available
if command -v zoxide >/dev/null 2>&1; then
    eval "$(zoxide init --cmd cd zsh)"
fi

# Load oh-my-posh theme (macOS only, skip on Linux)
if $IS_MACOS && command -v oh-my-posh &>/dev/null; then
    eval "$(oh-my-posh init zsh --config https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/amro.omp.json)"
fi

# Source organized configuration files
source "$HOME/.config/zsh/env"
source "$HOME/.config/zsh/plugins"
source "$HOME/.config/zsh/aliases"

# Completions (optimized)
autoload -Uz compinit
compinit -C
zinit cdreplay -q

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

# Completion styling with fzf-tab
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'
zstyle ':completion:*' menu no
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'eza --icons --color=always $realpath 2>/dev/null || ls --color $realpath'
zstyle ':fzf-tab:complete:__zoxide_z:*' fzf-preview 'eza --icons --color=always $realpath 2>/dev/null || ls --color $realpath'
zstyle ':fzf-tab:complete:(kill|ps):argument-rest' fzf-preview 'ps --pid=$word -o cmd --no-headers -w -w'
zstyle ':fzf-tab:complete:npm:*' fzf-preview 'cat package.json 2>/dev/null | jq .scripts 2>/dev/null || echo "No package.json found"'

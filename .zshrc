# Detect OS
OS_TYPE="$(uname -s)"
IS_MACOS=false
IS_LINUX=false
if [[ "$OS_TYPE" == "Darwin" ]]; then
    IS_MACOS=true
elif [[ "$OS_TYPE" == "Linux" ]]; then
    IS_LINUX=true
fi

# Homebrew setup (macOS only)
if $IS_MACOS && [[ -f "/opt/homebrew/bin/brew" ]]; then
    eval "$('/opt/homebrew/bin/brew' shellenv)"
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
export PNPM_HOME="$HOME/Library/pnpm"

# Set the directory we want to store zinit and plugins
ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"
if [ ! -d "$ZINIT_HOME" ]; then
    mkdir -p "$(dirname $ZINIT_HOME)"
    git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
fi

source "${ZINIT_HOME}/zinit.zsh"
source "$HOME/.config/zsh/z"

# Load oh-my-posh theme (macOS only, skip on Linux)
if $IS_MACOS && command -v oh-my-posh &>/dev/null; then
    eval "$(oh-my-posh init zsh --config https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/amro.omp.json)"
fi

# Source organized configuration files
source "$HOME/.config/zsh/env"
source "$HOME/.config/zsh/plugins"
source "$HOME/.config/zsh/aliases"

# Essential plugins only (lazy loaded for performance)
zinit wait lucid for \
    atinit"ZINIT[COMPINIT_OPTS]=-C; zicompinit; zicdreplay" \
    zsh-users/zsh-syntax-highlighting \
    atload"!_zsh_autosuggest_start" \
    zsh-users/zsh-autosuggestions \
    blockf \
    zsh-users/zsh-completions \
    atload"zicompinit; zicdreplay" \
    Aloxaf/fzf-tab

# Web dev specific snippets (minimal set)
zinit snippet OMZL::git.zsh
zinit snippet OMZP::git
zinit snippet OMZP::npm

    if ! command -v batcat &>/dev/null; then sudo apt install -y bat; fi
    if ! command -v rg &>/dev/null; then sudo apt install -y ripgrep; fi
    if ! command -v fd &>/dev/null; then sudo apt install -y fd-find; fi
    if ! command -v fzf &>/dev/null; then sudo apt install -y fzf; fi
    if ! command -v lazygit &>/dev/null; then sudo apt install -y lazygit; fi
    if ! command -v tldr &>/dev/null; then sudo apt install -y tldr; fi
    if ! command -v fastfetch &>/dev/null; then sudo apt install -y fastfetch; fi
fi

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

# Zoxide (better cd)
if command -v zoxide >/dev/null 2>&1; then
    eval "$(zoxide init --cmd cd zsh)"
fi

# Environment variables for modern tools
export BAT_THEME="TwoDark"
if $IS_LINUX; then
    # Ubuntu bat is 'batcat', alias for 'bat'
    if command -v batcat &>/dev/null; then
        alias bat='batcat'
    fi
    # Ubuntu fd is 'fdfind', alias for 'fd'
    if command -v fdfind &>/dev/null; then
        alias fd='fdfind'
    fi
fi
export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git --exclude node_modules'
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"

# Web dev aliases
alias ls='eza --icons --group-directories-first'
alias ll='eza --icons --group-directories-first -l'
alias la='eza --icons --group-directories-first -la'
alias tree='eza --tree --icons --level=2'
alias cat='bat'
alias grep='rg'
alias find='fd'

# Project shortcuts (customize as needed)
alias dev='cd ~/Projects && eza --icons'
alias shopify='cd ~/Projects/shopify && eza --icons'
alias next='cd ~/Projects/nextjs && eza --icons'

# Package manager shortcuts
alias ni='npm install'
alias nr='npm run'
alias ns='npm start'
alias nb='npm run build'
alias nd='npm run dev'
alias pi='pnpm install'
alias pr='pnpm run'
alias ps='pnpm start'
alias pb='pnpm run build'
alias pd='pnpm run dev'

# Git shortcuts (web dev focused)
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git pull'
alias gco='git checkout'
alias gb='git branch'
alias gd='git diff'
alias lg='lazygit'

# Docker (simplified, no conflicting completions)
if command -v docker &>/dev/null; then
    alias dc='docker-compose'
    alias dcu='docker-compose up'
    alias dcd='docker-compose down'
    alias dcb='docker-compose build'
fi

# Shopify CLI shortcuts (if installed)
if command -v shopify &>/dev/null; then
    alias sdev='shopify app dev'
    alias sgen='shopify app generate'
    alias sdeploy='shopify app deploy'
fi

# Fastfetch is installed for quick system info when you want it
# Just type 'fastfetch' in any terminal to see your system summary

# Dotfiles manager aliases
alias dotfiles='/Users/Christian.Brostrom/dotfiles/scripts/main.sh'
alias dotfiles-version='/Users/Christian.Brostrom/dotfiles/scripts/version.sh'

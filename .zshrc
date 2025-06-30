# =============================================================================
# CLEAN, STABLE ZSH CONFIGURATION
# =============================================================================
# This is a consolidated zsh configuration with all features in one file.
# No symlinks, no external dependencies, just one reliable .zshrc file.

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
# PATH SETUP
# =============================================================================
# Basic PATH setup
export PATH="$HOME/.local/bin:$PATH"
export GOPATH="$HOME/go"
export PATH="$GOPATH/bin:$PATH"

# Node/Web development environment
export NODE_OPTIONS="--max-old-space-size=8192"

# Cross-platform pnpm home
if $IS_MACOS; then
    export PNPM_HOME="$HOME/Library/pnpm"
else
    export PNPM_HOME="$HOME/.local/share/pnpm"
fi
export PATH="$PNPM_HOME:$PATH"

# =============================================================================
# HOMEBREW SETUP (macOS only)
# =============================================================================
if $IS_MACOS; then
    if [[ -f "/opt/homebrew/bin/brew" ]]; then
        eval "$('/opt/homebrew/bin/brew' shellenv)"
    elif [[ -f "/usr/local/bin/brew" ]]; then
        eval "$('/usr/local/bin/brew' shellenv)"
    fi
fi

# =============================================================================
# PLUGIN MANAGEMENT (zinit)
# =============================================================================
ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"

if [[ -f "${ZINIT_HOME}/zinit.zsh" ]]; then
    source "${ZINIT_HOME}/zinit.zsh"

    # Load stable plugins
    zinit wait lucid for \
        zsh-users/zsh-completions \
        OMZL::git.zsh \
        OMZP::git \
        OMZP::npm \
        lukechilds/zsh-nvm

    # Load fzf integration
    zinit wait lucid for \
        https://github.com/junegunn/fzf/raw/master/shell/{'completion','key-bindings'}.zsh

    # Load autosuggestions (stable version)
    zinit wait lucid for zsh-users/zsh-autosuggestions

    # Load syntax highlighting last (stable version)
    zinit wait lucid for zsh-users/zsh-syntax-highlighting
fi

# =============================================================================
# PROMPT SETUP
# =============================================================================
# Starship prompt (if available)
if command -v starship &>/dev/null; then
    eval "$(starship init zsh)"
fi

# =============================================================================
# ENVIRONMENT TOOLS
# =============================================================================
# Direnv for project-specific env vars
if command -v direnv &>/dev/null; then
    eval "$(direnv hook zsh)"
fi

# =============================================================================
# COMPLETIONS
# =============================================================================
autoload -Uz compinit
compinit

# =============================================================================
# HISTORY CONFIGURATION
# =============================================================================
HISTSIZE=10000
HISTFILE=~/.zsh_history
SAVEHIST=$HISTSIZE
setopt appendhistory sharehistory hist_ignore_space hist_ignore_all_dups

# =============================================================================
# KEYBINDINGS
# =============================================================================
# Smart history search
autoload -U up-line-or-beginning-search down-line-or-beginning-search
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search
bindkey "^[[A" up-line-or-beginning-search
bindkey "^[[B" down-line-or-beginning-search

# FZF keybindings (if available)
if command -v fzf &>/dev/null; then
    bindkey '^R' fzf-history-widget
    bindkey '^T' fzf-file-widget
    bindkey '^[c' fzf-cd-widget
fi

# --- FZF ADVANCED INTEGRATION ---
# Keybindings (Ctrl-R for history, Ctrl-T for files, Alt-C for dirs)
if command -v fzf >/dev/null 2>&1; then
    export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
    export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
    export FZF_ALT_C_COMMAND='fd --type d --hidden --follow --exclude .git'
    export FZF_DEFAULT_OPTS='--height 40% --layout=reverse --border --preview "bat --style=numbers --color=always --line-range :500 {} 2>/dev/null || cat {} 2>/dev/null || tree -C {} 2>/dev/null"'
    # Git integration
    fzf-git() {
        git log --oneline --graph --color=always | fzf --ansi --preview 'echo {} | cut -d" " -f1 | xargs -I % git show --color=always %'
    }
    alias gco='git checkout $(git branch | fzf)'
    alias gcb='git checkout -b $(echo | fzf)'
    alias gcm='git checkout $(git branch | fzf)'
    alias gcf='git commit --fixup $(git log --oneline | fzf | awk "{print \$1}")'
    alias gpick='git cherry-pick $(git log --oneline | fzf | awk "{print \$1}")'
    # Directory jumping
    alias j='zoxide query -l | fzf --tac | xargs -r cd'
    # File search
    alias ff='fzf --preview "bat --style=numbers --color=always --line-range :500 {} 2>/dev/null || cat {} 2>/dev/null"'
    # History search
    bindkey '^R' fzf-history-widget
fi

# --- LSD (EXA REPLACEMENT) ALIASES ---
if command -v lsd >/dev/null 2>&1; then
    alias ls='lsd'
    alias ll='lsd -l'
    alias la='lsd -la'
    alias lt='lsd --tree'
    alias lsg='lsd --group-dirs=first'
    alias lsdot='lsd -a | grep "^\."'
    alias lsl='lsd -l --color=always'
    alias lsh='lsd -lh'
fi
# --- END LSD/FZF ---

# =============================================================================
# MODERN TOOL ALIASES
# =============================================================================
# bat (better cat) aliases
if command -v bat &>/dev/null; then
    alias cat='bat'
    alias less='bat'
elif command -v batcat &>/dev/null; then
    alias cat='batcat'
    alias less='batcat'
fi

# ripgrep (better grep) aliases
if command -v rg &>/dev/null; then
    alias grep='rg'
fi

# fd (better find) aliases
if command -v fd &>/dev/null; then
    alias find='fd'
elif command -v fdfind &>/dev/null; then
    alias find='fdfind'
fi

# =============================================================================
# WEB DEVELOPMENT ALIASES
# =============================================================================
# Project shortcuts
alias dev='cd ~/Projects && ls'
alias shopify='cd ~/Projects/shopify && ls'
alias next='cd ~/Projects/nextjs && ls'

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

# =============================================================================
# GIT ALIASES
# =============================================================================
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git pull'
alias gco='git checkout'
alias gb='git branch'
alias gd='git diff'

# Modern git tools
if command -v lazygit &>/dev/null; then
    alias lg='lazygit'
fi

if command -v git-fuzzy &>/dev/null; then
    alias fuzzy='git-fuzzy'
fi

if command -v delta &>/dev/null; then
    alias diff='delta'
fi

# =============================================================================
# SYSTEM TOOL ALIASES
# =============================================================================
# Process and system monitoring
if command -v procs &>/dev/null; then
    alias ps='procs'
fi

if command -v htop &>/dev/null; then
    alias h='htop'
fi

if command -v bottom &>/dev/null; then
    alias top='bottom'
fi

# Disk usage
if command -v ncdu &>/dev/null; then
    alias disk='ncdu'
fi

if command -v du-dust &>/dev/null; then
    alias du='du-dust'
fi

# Search tools
if command -v rga &>/dev/null; then
    alias search='rga'
elif command -v rg &>/dev/null; then
    alias search='rg'
fi

# Help and documentation
if command -v tldr &>/dev/null; then
    alias help='tldr'
fi

# Text processing
if command -v sd &>/dev/null; then
    alias sed='sd'
fi

# =============================================================================
# DOCKER ALIASES
# =============================================================================
if command -v docker &>/dev/null; then
    alias dc='docker-compose'
    alias dcu='docker-compose up'
    alias dcd='docker-compose down'
    alias dcb='docker-compose build'
fi

# =============================================================================
# SHOPIFY CLI ALIASES
# =============================================================================
if command -v shopify &>/dev/null; then
    alias sdev='shopify app dev'
    alias sgen='shopify app generate'
    alias sdeploy='shopify app deploy'
fi

# =============================================================================
# PLATFORM-SPECIFIC ALIASES
# =============================================================================
# Linux-specific aliases
if [[ "$(uname -s)" == "Linux" ]]; then
    # Ubuntu bat is 'batcat', alias for 'bat'
    if command -v batcat &>/dev/null; then
        alias bat='batcat'
    fi
    # Ubuntu fd is 'fdfind', alias for 'fd'
    if command -v fdfind &>/dev/null; then
        alias fd='fdfind'
    fi
fi

# --- FZF-TAB PLUGIN (fuzzy tab completion) ---
if command -v zinit >/dev/null 2>&1; then
    zinit light Aloxaf/fzf-tab
else
    # Manual fallback: clone and source if not using a plugin manager
    if [[ -d "$HOME/.fzf-tab" ]]; then
        source "$HOME/.fzf-tab/fzf-tab.plugin.zsh"
    fi
fi
# --- END FZF-TAB ---

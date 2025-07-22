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
# PATH SETUP
# =============================================================================
# Basic PATH setup
export PATH="$HOME/.local/bin:$PATH"
export GOPATH="$HOME/go"
export PATH="$GOPATH/bin:$PATH"

# Node/Web development environment
export NODE_OPTIONS="--max-old-space-size=8192"

# npm configuration (no pnpm)
export NPM_CONFIG_FUND=false
export NPM_CONFIG_AUDIT=false

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
# ASDF VERSION MANAGER
# =============================================================================
# Load asdf if available (handle both git and Homebrew installations)
if [[ -f "$HOME/.asdf/asdf.sh" ]]; then
    # Git installation
    . "$HOME/.asdf/asdf.sh"
    . "$HOME/.asdf/completions/asdf.bash"
elif command -v asdf >/dev/null 2>&1; then
    # Homebrew installation - asdf is already in PATH
    log_info "asdf available via Homebrew"
else
    log_warning "asdf not found - install via Homebrew or git"
fi

# Load asdf-direnv integration if direnv is available
if command -v direnv >/dev/null 2>&1; then
    eval "$(asdf exec direnv hook zsh)"
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
        OMZP::npm

    # Note: NVM replaced by asdf for Node.js management

    # Load fzf integration
    zinit wait lucid for \
        https://github.com/junegunn/fzf/raw/master/shell/{'completion','key-bindings'}.zsh

    # Load autosuggestions (stable version)
    zinit wait lucid for zsh-users/zsh-autosuggestions

    # Load syntax highlighting last (stable version)
    zinit wait lucid for zsh-users/zsh-syntax-highlighting

    # Load fzf-tab for visual completion
    zinit light Aloxaf/fzf-tab
fi

# =============================================================================
# FZF CONFIGURATION
# =============================================================================
# Preview function for fzf-tab
preview-files() {
    local file="$1"
    if [[ -d "$file" ]]; then
        # Directory preview
        if command -v lsd >/dev/null 2>&1; then
            lsd --tree --level=2 "$file" 2>/dev/null || ls -la "$file"
        else
            ls -la "$file"
        fi
    elif [[ -f "$file" ]]; then
        # File preview
        if command -v bat >/dev/null 2>&1; then
            bat --style=numbers --color=always "$file" 2>/dev/null || cat "$file"
        else
            cat "$file"
        fi
    fi
}

# FZF configuration
export FZF_DEFAULT_OPTS="--height=40% --border --preview-window=right:60% --preview='preview-files {}'"
export FZF_DEFAULT_COMMAND="fd --type f --hidden --follow --exclude .git --exclude node_modules --exclude .cache"
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_ALT_C_COMMAND="fd --type d --hidden --follow --exclude .git --exclude node_modules --exclude .cache"

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
# ASDF CONFIGURATION
# =============================================================================
# asdf aliases for common operations
alias asdfls='asdf list'
alias asdfuse='asdf local'
alias asdfinstall='asdf install'
alias asdfcurrent='asdf current'
alias asdfglobal='asdf global'
alias asdflocal='asdf local'

# Quick Node.js version switching aliases (via asdf)
alias node16='asdf local nodejs 16'
alias node18='asdf local nodejs 18'
alias node20='asdf local nodejs 20'
alias node21='asdf local nodejs 21'
alias nodelts='asdf local nodejs latest:lts'
alias nodestable='asdf local nodejs latest'

# Quick Python version switching aliases (via asdf)
alias python3.9='asdf local python 3.9'
alias python3.10='asdf local python 3.10'
alias python3.11='asdf local python 3.11'
alias python3.12='asdf local python 3.12'
alias pythonlatest='asdf local python latest'

# Quick Go version switching aliases (via asdf)
alias go1.20='asdf local golang 1.20'
alias go1.21='asdf local golang 1.21'
alias go1.22='asdf local golang 1.22'
alias golatest='asdf local golang latest'

# Quick Rust version switching aliases (via asdf)
alias ruststable='asdf local rust stable'
alias rustnightly='asdf local rust nightly'
alias rustlatest='asdf local rust latest'

# =============================================================================
# ZOXIDE SETUP (Smart Directory Navigation)
# =============================================================================
if command -v zoxide &>/dev/null; then
    eval "$(zoxide init zsh)"

    # Optimized zoxide configuration
    export _ZO_FZF_OPTS="--height 40% --layout=reverse --border --preview 'lsd --tree --level=2 {} 2>/dev/null || tree -C {} 2>/dev/null'"
    export _ZO_ECHO=1
    export _ZO_EXCLUDE_DIRS="$HOME/.cache:$HOME/.local/share:$HOME/.npm:$HOME/.pnpm-store:$HOME/.cargo/registry"

    # Enhanced zoxide aliases with fzf integration
    alias zi='zoxide query -i' # Interactive query with fzf
    alias za='zoxide add'      # Add current directory
    alias zr='zoxide remove'   # Remove directory from database
    alias zq='zoxide query'    # Query without jumping
    alias zl='zoxide query -l' # List all directories

    # Smart directory jumping with fzf
    alias j='zoxide query -i'
    alias jj='zoxide query -i'

    # Quick project navigation
    alias dev='zoxide query -i ~/Projects'
    alias work='zoxide query -i ~/Work'
    alias docs='zoxide query -i ~/Documents'

    # Git repository navigation
    alias repos='zoxide query -i $(find ~/Projects ~/Work -name ".git" -type d 2>/dev/null | sed "s/\/.git//" | sort -u)'
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
    # Directory jumping (now handled by zoxide section above)
    # alias j='zoxide query -l | fzf --tac | xargs -r cd'
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

# Package manager shortcuts (npm only)
alias ni='npm install'
alias nr='npm run'
alias ns='npm start'
alias nb='npm run build'
alias nd='npm run dev'
alias nci='npm ci'
alias nup='npm update'
alias nls='npm list'
alias nout='npm outdated'

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
# DOTFILES ALIAS
# =============================================================================
# Function to find and run dotfiles manager from anywhere
dotfiles() {
    # Try to find dotfiles.sh in common locations
    local dotfiles_path=""
    
    # Check if we're in a dotfiles directory
    if [[ -f "./dotfiles.sh" ]]; then
        dotfiles_path="./dotfiles.sh"
    # Check common installation paths
    elif [[ -f "$HOME/dotfiles/dotfiles.sh" ]]; then
        dotfiles_path="$HOME/dotfiles/dotfiles.sh"
    elif [[ -f "$HOME/.dotfiles/dotfiles.sh" ]]; then
        dotfiles_path="$HOME/.dotfiles/dotfiles.sh"
    # Search in git repositories
    elif command -v git >/dev/null 2>&1; then
        # Find git root and check for dotfiles.sh
        local git_root=$(git rev-parse --show-toplevel 2>/dev/null)
        if [[ -n "$git_root" ]] && [[ -f "$git_root/dotfiles.sh" ]]; then
            dotfiles_path="$git_root/dotfiles.sh"
        fi
    fi
    
    if [[ -n "$dotfiles_path" ]]; then
        "$dotfiles_path" "$@"
    else
        echo "Error: dotfiles.sh not found"
        echo "Please ensure you're in a dotfiles directory or have dotfiles installed in ~/dotfiles or ~/.dotfiles"
        return 1
    fi
}

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

# Configure fzf-tab for better visual completion
if command -v fzf-tab >/dev/null 2>&1 || [[ -n "$FZF_TAB_HOME" ]]; then
    # Enable fzf-tab
    enable-fzf-tab
    
    # Configure fzf-tab appearance
    zstyle ':fzf-tab:*' fzf-command fzf
    zstyle ':fzf-tab:*' fzf-flags --height=40% --border --preview-window=right:60%
    
    # Configure completion colors
    zstyle ':fzf-tab:complete:*:*' fzf-preview 'preview-files $realpath'
    
    # Git completion
    zstyle ':fzf-tab:complete:git-(add|diff|restore):*' fzf-preview 'git diff $word | delta 2>/dev/null || git diff $word'
    zstyle ':fzf-tab:complete:git-log:*' fzf-preview 'git log --color=always $word'
    zstyle ':fzf-tab:complete:git-help:*' fzf-preview 'git help $word | bat -l man 2>/dev/null || git help $word'
    
    # Directory completion
    zstyle ':fzf-tab:complete:cd:*' fzf-preview 'lsd --tree --level=2 $realpath 2>/dev/null || ls -la $realpath'
    
    # Process completion
    zstyle ':fzf-tab:complete:kill:*' fzf-preview 'ps -p $word -o pid,ppid,cmd --no-headers 2>/dev/null || echo "Process: $word"'
    
    # Package completion
    zstyle ':fzf-tab:complete:brew-(install|uninstall|search):*' fzf-preview 'brew info $word 2>/dev/null || echo "Package: $word"'
    
    # File completion with preview
    zstyle ':fzf-tab:complete:*:*' fzf-preview 'preview-files $realpath'
fi
# --- END FZF-TAB ---

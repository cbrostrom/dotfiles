# =============================================================================
# ALIASES
# =============================================================================
# Modern tool replacements and convenient shortcuts

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

# lsd (better ls) aliases
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

# =============================================================================
# WEB DEVELOPMENT ALIASES
# =============================================================================
# Project shortcuts
alias dev='cd ~/Projects && ls'

# npm shortcuts
alias ni='npm install'
alias nr='npm run'
alias ns='npm start'
alias nb='npm run build'
alias nd='npm run dev'
alias nci='npm ci'
alias nup='npm update'
alias nls='npm list'
alias nout='npm outdated'
alias nupg='npx npm-check-updates'

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

# FZF-enhanced git aliases
if command -v fzf &>/dev/null; then
    alias gcof='git checkout $(git branch | fzf)'
    alias gcb='git checkout -b $(echo | fzf)'
    alias gcm='git checkout $(git branch | fzf)'
    alias gcf='git commit --fixup $(git log --oneline | fzf | awk "{print \$1}")'
    alias gpick='git cherry-pick $(git log --oneline | fzf | awk "{print \$1}")'
fi

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


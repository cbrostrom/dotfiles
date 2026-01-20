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

# eza (better ls) aliases - modern ls replacement with git integration
if command -v eza >/dev/null 2>&1; then
    alias ls='eza --icons --group-directories-first'
    alias ll='eza -l --icons --group-directories-first --git'
    alias la='eza -la --icons --group-directories-first --git'
    alias lt='eza --tree --icons --level=2'
    alias tree='eza --tree --icons'
    alias lsg='eza --group-directories-first'
    alias lsdot='eza -a | grep "^\."'
    alias lsl='eza -l --icons --color=always --git'
    alias lsh='eza -lh --icons --git'
    alias lsa='eza -lah --icons --git'
    alias lsmod='eza -l --icons --sort=modified --reverse'
    alias lssize='eza -l --icons --sort=size --reverse'
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
# Basic git commands
alias gs='git status'
alias ga='git add'
alias gaa='git add --all'
alias gc='git commit'
alias gcm='git commit -m'
alias gca='git commit --amend'
alias gcan='git commit --amend --no-edit'
alias gp='git push'
alias gpf='git push --force-with-lease'
alias gl='git pull'
alias gf='git fetch'
alias gfa='git fetch --all'

# Branch management
alias gco='git checkout'
alias gcb='git checkout -b'
alias gb='git branch'
alias gba='git branch -a'
alias gbd='git branch -d'
alias gbD='git branch -D'
alias gm='git merge'
alias grb='git rebase'
alias grbi='git rebase -i'
alias grbc='git rebase --continue'
alias grba='git rebase --abort'

# Diff and log
alias gd='git diff'
alias gdc='git diff --cached'
alias gdw='git diff --word-diff'
alias glog='git log --oneline --decorate --graph'
alias gloga='git log --oneline --decorate --graph --all'
alias glogp='git log --graph --pretty=format:"%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset"'

# Stash management
alias gst='git stash'
alias gstp='git stash pop'
alias gstl='git stash list'
alias gstd='git stash drop'
alias gsta='git stash apply'

# Reset and clean
alias grh='git reset HEAD'
alias grhh='git reset --hard HEAD'
alias gclean='git clean -fd'

# Remote management
alias gr='git remote'
alias grv='git remote -v'
alias gra='git remote add'
alias grrm='git remote remove'

# Show and blame
alias gshow='git show'
alias gblame='git blame'

# Tags
alias gt='git tag'
alias gtl='git tag -l'

# Worktree
alias gwt='git worktree'
alias gwta='git worktree add'
alias gwtl='git worktree list'
alias gwtr='git worktree remove'

# FZF-enhanced git aliases
if command -v fzf &>/dev/null; then
    alias gcof='git checkout $(git branch | fzf)'
    alias gcm='git checkout $(git branch | fzf)'
    alias gcf='git commit --fixup $(git log --oneline | fzf | awk "{print \$1}")'
    alias gpick='git cherry-pick $(git log --oneline | fzf | awk "{print \$1}")'
    alias gdf='git diff $(git branch | fzf)'
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

# bottom binary is called 'btm' on most systems
if command -v btm &>/dev/null; then
    alias top='btm'
    alias bottom='btm'
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
    # Docker Compose
    alias dc='docker-compose'
    alias dcu='docker-compose up'
    alias dcd='docker-compose down'
    alias dcb='docker-compose build'
    
    # Docker Cleanup
    alias dprune='docker system prune -af --volumes'
    alias dclean='docker container prune -f && docker image prune -af'
    alias dstop='docker stop $(docker ps -aq)'
    alias drm='docker rm $(docker ps -aq)'
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
# SECURITY MONITORING ALIASES
# =============================================================================
if [[ "$(uname -s)" == "Linux" ]]; then
    # SSH monitoring
    alias sshstatus='sudo systemctl status sshd'
    alias sshrestart='sudo systemctl restart sshd'
    alias sshlog='sudo journalctl -u sshd -f'
    
    # Fail2ban monitoring
    alias f2bstatus='sudo fail2ban-client status'
    alias f2bssh='sudo fail2ban-client status sshd'
    alias f2bunban='sudo fail2ban-client set sshd unbanip'
    
    # Firewall monitoring
    alias fwstatus='sudo ufw status numbered'
    alias fwreload='sudo ufw reload'
    
    # Network monitoring
    alias ports='sudo ss -tlnp'
    alias listening='sudo ss -tlnp | grep LISTEN'
    alias connections='sudo ss -tnp'
fi

# =============================================================================
# TAILSCALE ALIASES
# =============================================================================
if command -v tailscale &>/dev/null; then
    alias tsstatus='tailscale status'
    alias tsup='tailscale up'
    alias tsdown='tailscale down'
    alias tsip='tailscale ip -4'
    alias tsping='tailscale ping'
fi

# =============================================================================
# STREAMING (APOLLO/SUNSHINE) ALIASES
# =============================================================================
if [[ "$(uname -s)" == "Linux" ]]; then
    alias apollostatus='systemctl --user status apollo'
    alias apollorestart='systemctl --user restart apollo'
    alias apollolog='journalctl --user -u apollo -f'
    alias apolloconfig='micro ~/.config/sunshine/sunshine.conf'
fi

# =============================================================================
# GSCONNECT/KDE CONNECT ALIASES
# =============================================================================
if [[ "$(uname -s)" == "Linux" ]]; then
    alias gsconnect='gnome-extensions prefs gsconnect@andyholmes.github.io'
    alias gsconnect-restart='gnome-extensions disable gsconnect@andyholmes.github.io && sleep 1 && gnome-extensions enable gsconnect@andyholmes.github.io'
    alias gsconnect-status='gnome-extensions info gsconnect@andyholmes.github.io | grep -E "State|Enabled"'
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


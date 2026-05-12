# =============================================================================
# ALIASES
# =============================================================================
# Modern tool replacements and convenient shortcuts

# =============================================================================
# NAVIGATION ALIASES
# =============================================================================
alias ..='cd ..'

# Zoxide aliases - use both 'z' and ',' for directory jumping
if command -v zoxide &>/dev/null; then
    alias .='z'
fi

# =============================================================================
# MODERN TOOL ALIASES
# =============================================================================
# Policy: Do NOT override POSIX tools (cat/less/grep/find/sed/diff/ps).
# Scripts and muscle memory rely on them. Use short aliases instead.

# bat (better cat) — short alias 'b'; pager 'less' stays POSIX
if command -v bat &>/dev/null; then
    alias b='bat'
elif command -v batcat &>/dev/null; then
    alias b='batcat'
    alias bat='batcat'
fi

# ripgrep — short alias 'rgi' for case-insensitive; 'grep' stays POSIX
if command -v rg &>/dev/null; then
    alias rgi='rg -i'
fi

# fd (better find) — short alias 'fdf'; 'find' stays POSIX
if command -v fd &>/dev/null; then
    : # 'fd' is already the binary name on most systems
elif command -v fdfind &>/dev/null; then
    alias fd='fdfind'
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
# Project shortcut (single source of truth — overrides any earlier alias)
alias dev='cd ~/Projects && ls'

# Package manager shortcuts are defined as smart functions in 04-functions.zsh
# They auto-detect the correct pm (bun/npm/pnpm/yarn) from the project lockfile.
# Run `pm` to see all available commands, `pm which` to see detected manager.

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
# Note: 'gcm' is reserved for 'git commit -m' above — use gcof/gbf for fzf branch picker
if command -v fzf &>/dev/null; then
    alias gcof='git checkout $(git branch | fzf)'
    alias gbf='git checkout $(git branch | fzf)'
    gcf()    { git commit --fixup "$(git log --oneline | fzf | awk '{print $1}')"; }
    gpick()  { git cherry-pick "$(git log --oneline | fzf | awk '{print $1}')"; }
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
    alias dlt='delta'
fi

# =============================================================================
# SYSTEM TOOL ALIASES
# =============================================================================
# Process and system monitoring (do not override POSIX 'ps' / 'top')
if command -v procs &>/dev/null; then
    alias prc='procs'
fi

if command -v htop &>/dev/null; then
    alias h='htop'
fi

if command -v btm &>/dev/null; then
    alias btm='btm'
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

# Text processing — 'sd' has DIFFERENT syntax from sed; do NOT override
# (use 'sd' directly; alias kept here only for discoverability)

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
# SSH HOST ALIASES
# =============================================================================
alias superbro='ssh christian@100.100.1.50 -p 27789'
alias linuxbro='ssh christian@100.100.1.100 -p 27789'

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
# STREAMING (SUNSHINE) ALIASES
# =============================================================================
if [[ "$(uname -s)" == "Linux" ]]; then
    # Sunshine service management
    alias sunstatus='systemctl --user status sunshine'
    alias sunrestart='systemctl --user restart sunshine'
    alias sunlog='journalctl --user -u sunshine -f'
    alias sunconfig='micro ~/.config/sunshine/sunshine.conf'
    alias sunapps='micro ~/.config/sunshine/apps.json'
    
    # Steam sync (apollo-steam-sync works with Sunshine too)
    alias sunsync='apollo-steam-sync && systemctl --user restart sunshine'
    alias sungames='apollo-steam-sync --list'
    alias sunfix='apollo-steam-sync --fix-cover'
    alias sunlaunch='apollo-steam-sync --launch-mode && systemctl --user restart sunshine'

    # Display management
    alias screenctrl='screencontrol'
    alias fixdisplay='fix-display-priority'
    alias recoverdisplay='recover-display'
    alias displaylog='tail -f /tmp/display-monitor.log'
fi

# =============================================================================
# CLAUDE CODE LAUNCHERS
# =============================================================================
# Core
# cc/ccc auto-route through `cmux claude-teams` when inside cmux so spawned
# subagents become native cmux splits with sidebar metadata. Falls back to
# plain `claude` outside cmux.
cc() {
  if [[ -n "$CMUX_WORKSPACE_ID" ]]; then
    command cmux claude-teams "$@"
  else
    command claude "$@"
  fi
}
ccc() {
  if [[ -n "$CMUX_WORKSPACE_ID" ]]; then
    command cmux claude-teams --continue "$@"
  else
    command claude --continue "$@"
  fi
}
alias ccr='claude --resume'                        # built-in resume picker
alias ccf='claude --continue --fork-session'       # fork most recent into new session
alias cct='cmux claude-teams'                      # explicit teams launcher (any context)

# Custom pickers (~/.local/bin)
alias ccp='claude-pick'                            # fuzzy-pick project to start in
alias ccrp='claude-resume-pick'                    # fuzzy-pick past session to resume
alias ccw='claude-worktree-pick'                   # fuzzy-pick git worktree

# Modes
alias ccy='claude --dangerously-skip-permissions'  # YOLO: skip permission prompts
alias ccb='claude --bare'                          # minimal mode (no hooks/MCP/skills)
alias ccd='claude --debug'                         # debug mode
alias cci='claude --ide'                           # auto-connect IDE
alias ccq='claude -p'                              # one-shot print (non-interactive)

# Subcommands
alias ccdoc='claude doctor'
alias ccup='claude update'
alias ccmcp='claude mcp'
alias ccpl='claude plugins'
alias ccag='claude agents'
alias ccauth='claude auth'

# PR resume (interactive picker if no arg)
alias ccpr='claude --from-pr'

# =============================================================================
# SYSTEM UPDATE ALIASES
# =============================================================================
if [[ "$(uname -s)" == "Linux" ]]; then
    # Debian/Ubuntu (apt)
    if command -v apt &>/dev/null; then
        alias systemupdate='echo "🔄 Updating system packages..." && sudo apt update && sudo apt upgrade -y && command -v flatpak &>/dev/null && echo "🔄 Updating Flatpak..." && flatpak update -y'
    elif command -v apt-get &>/dev/null; then
        alias systemupdate='echo "🔄 Updating system packages..." && sudo apt-get update && sudo apt-get upgrade -y && command -v flatpak &>/dev/null && echo "🔄 Updating Flatpak..." && flatpak update -y'
    fi

    # LinuxBro network shares
    alias linuxbro-setup='$DOTFILES_DIR/linux/setup-linuxbro-symlinks.sh'
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

alias pod='podman'

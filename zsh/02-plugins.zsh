# =============================================================================
# PLUGIN MANAGEMENT
# =============================================================================
# zinit plugins, completions, and FZF integration

# =============================================================================
# ZINIT PLUGIN MANAGER
# =============================================================================
ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"

if [[ -f "${ZINIT_HOME}/zinit.zsh" ]]; then
    source "${ZINIT_HOME}/zinit.zsh"

    # Load critical plugins first (no wait) for immediate availability
    zinit light-mode for \
        zsh-users/zsh-autosuggestions \
        zsh-users/zsh-syntax-highlighting

    # Load completions and other plugins with lazy loading
    zinit wait lucid for \
        zsh-users/zsh-completions \
        OMZL::git.zsh \
        OMZP::git \
        OMZP::npm

    # Note: Node.js managed by fnm (Fast Node Manager) for better .nvmrc support

    # Load fzf-tab for visual completion
    zinit light Aloxaf/fzf-tab
fi

# =============================================================================
# FZF CONFIGURATION (Consolidated)
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

# FZF default options with preview
export FZF_DEFAULT_OPTS='--height 40% --layout=reverse --border --preview "bat --style=numbers --color=always --line-range :500 {} 2>/dev/null || cat {} 2>/dev/null || tree -C {} 2>/dev/null"'
export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git --exclude node_modules --exclude .cache'
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_ALT_C_COMMAND='fd --type d --hidden --follow --exclude .git --exclude node_modules --exclude .cache'

# FZF keybindings and completion
if command -v fzf &>/dev/null; then
    # Load fzf integration
    zinit wait lucid for \
        https://github.com/junegunn/fzf/raw/master/shell/{'completion','key-bindings'}.zsh
    
    # Keybindings
    bindkey '^R' fzf-history-widget
    bindkey '^T' fzf-file-widget
    bindkey '^[c' fzf-cd-widget
    
    # Git integration
    fzf-git() {
        git log --oneline --graph --color=always | fzf --ansi --preview 'echo {} | cut -d" " -f1 | xargs -I % git show --color=always %'
    }
    
    # File search
    alias ff='fzf --preview "bat --style=numbers --color=always --line-range :500 {} 2>/dev/null || cat {} 2>/dev/null"'
fi

# =============================================================================
# FZF-TAB CONFIGURATION
# =============================================================================
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

# =============================================================================
# ZOXIDE SETUP (Smart Directory Navigation)
# =============================================================================
if command -v zoxide &>/dev/null; then
    # Unalias zi if it exists to prevent conflict with zinit
    if alias zi >/dev/null 2>&1; then
        unalias zi
    fi

    eval "$(zoxide init zsh)"

    # Optimized zoxide configuration
    export _ZO_FZF_OPTS="--height 40% --layout=reverse --border --preview 'lsd --tree --level=2 {} 2>/dev/null || tree -C {} 2>/dev/null'"
    export _ZO_ECHO=1
    export _ZO_EXCLUDE_DIRS="$HOME/.cache:$HOME/.local/share:$HOME/.npm:$HOME/.pnpm-store:$HOME/.cargo/registry"

    # Enhanced zoxide aliases with fzf integration
    alias zj='zoxide query -i' # Interactive query with fzf (changed from zi to avoid zinit conflict)
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
# COMPLETIONS (Optimized with Caching)
# =============================================================================
autoload -Uz compinit

# Only check compinit once a day for performance
# This significantly speeds up shell startup
if [[ -n ${HOME}/.zcompdump(#qNmh+24) ]]; then
    compinit -d "${HOME}/.zcompdump"
else
    compinit -C -d "${HOME}/.zcompdump"
fi

# Local per-machine aliases (not tracked in git)
if [[ -f "$HOME/.local-aliases" ]]; then
  . "$HOME/.local-aliases"
fi

# Case insensitive path completion
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'
zstyle ':completion:*' menu select

# Completion optimizations
zstyle ':completion:*' accept-exact '*(N)'
zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path $HOME/.zsh_cache
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}
zstyle ':completion:*' group-name ''
zstyle ':completion:*' verbose yes
zstyle ':completion:*' format 'Completing %d'
zstyle ':completion:*' list-prompt '%SAt %p: Hit TAB for more, or the character to insert%s'
zstyle ':completion:*' select-prompt '%SScrolling active: current selection at %p%s'

# Smart completion behavior
zstyle ':completion:*' completer _expand _complete _correct _approximate
zstyle ':completion:*' expand prefix suffix
zstyle ':completion:*' approximate 1
zstyle ':completion:*' max-errors 2

# Directory completion
zstyle ':completion:*' squeeze-slashes true
zstyle ':completion:*' ignore-parents parent pwd

# File completion
zstyle ':completion:*' file-patterns '%p(D-/):directories:%F' '%p(-/):directories:%F' '%p(-):all-files:%F'
zstyle ':completion:*' file-sort modification reverse

# Process completion
zstyle ':completion:*:processes' command 'ps -ax'
zstyle ':completion:*:processes' sort false
zstyle ':completion:*:processes-names' command 'ps axho command'

# Git completion enhancements (only if git-completion.bash exists)
if [[ -f "$HOME/.zsh/git-completion.bash" ]]; then
    zstyle ':completion:*:*:git:*' script $HOME/.zsh/git-completion.bash
    zstyle ':completion:*:git:*' tag-order local-tags remote-tags
fi

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

# =============================================================================
# PROMPT SETUP
# =============================================================================
# Starship prompt (if available)
if command -v starship &>/dev/null; then
    eval "$(starship init zsh)"
fi

# =============================================================================
# FNM (Fast Node Manager) - Primary Node.js Version Manager
# =============================================================================
if command -v fnm &>/dev/null; then
    export FNM_COREPACK_ENABLED=true
    eval "$(fnm env --use-on-cd)"

    # Alias fnm as nvm for compatibility
    alias nvm='fnm'

    # Quick Node.js version switching aliases
    alias node16='fnm use 16'
    alias node18='fnm use 18'
    alias node20='fnm use 20'
    alias node22='fnm use 22'
    alias nodelts='fnm use lts-latest'
    alias nodelatest='fnm use latest'

    # fnm management aliases
    alias fnmls='fnm list'
    alias fnmi='fnm install'
    alias fnmuse='fnm use'
    alias fnmdefault='fnm default'
fi


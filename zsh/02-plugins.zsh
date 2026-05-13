# shellcheck shell=bash disable=SC1073,SC1036,SC1072
# (zsh glob qualifiers like (#qNmh+24) are valid zsh but unknown to shellcheck)
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
        zsh-users/zsh-autosuggestions

    # Load completions and other plugins with lazy loading
    zinit wait lucid for \
        zsh-users/zsh-completions \
        OMZL::git.zsh \
        OMZP::git \
        OMZP::npm

    # Note: Node.js managed by fnm (Fast Node Manager)

    # Load fzf-tab for visual completion
    zinit light Aloxaf/fzf-tab

    # Fast syntax highlighting (compinit is run explicitly later in this file —
    # no zicompinit needed here; just replay cached completions after load)
    zinit ice wait lucid atload'zicdreplay'
    zinit light zdharma-continuum/fast-syntax-highlighting
fi

# =============================================================================
# COMPLETION OPTIMIZATION (Moved to end to avoid duplicate)
# =============================================================================
# Note: compinit is called at the end of this file to avoid duplicate calls

# =============================================================================
# FZF CONFIGURATION (Consolidated)
# =============================================================================
# Preview function for fzf-tab
preview-files() {
    local file="$1"
    if [[ -d "$file" ]]; then
        # Directory preview
        if command -v eza >/dev/null 2>&1; then
            eza --tree --icons --level=2 "$file" 2>/dev/null || ls -la "$file"
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
if (( $+commands[fzf] )); then
    # Load fzf integration immediately (no wait) to register widgets before syntax highlighting
    zinit lucid for \
        https://github.com/junegunn/fzf/raw/master/shell/{'completion','key-bindings'}.zsh
    
    # Keybindings
    bindkey '^R' fzf-history-widget
    # bindkey '^T' fzf-file-widget  # Disabled: Conflicts with Ghostty new tab
    bindkey '^F' fzf-file-widget    # Use Ctrl+F instead for file search
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
    zstyle ':fzf-tab:complete:cd:*' fzf-preview 'eza --tree --icons --level=2 $realpath 2>/dev/null || ls -la $realpath'
    
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
if (( $+commands[zoxide] )); then
    # Unalias zi if it exists to prevent conflict with zinit
    (( $+aliases[zi] )) && unalias zi

    # Use cached eval if available, otherwise run directly
    if typeset -f _cached_eval >/dev/null; then
        _cached_eval "zoxide" "zoxide init zsh"
    else
        eval "$(zoxide init zsh)"
    fi

    # Optimized zoxide configuration
    export _ZO_FZF_OPTS="--height 40% --layout=reverse --border --preview 'eza --tree --icons --level=2 {} 2>/dev/null || tree -C {} 2>/dev/null'"
    export _ZO_ECHO=1
    export _ZO_EXCLUDE_DIRS="$HOME/.cache:$HOME/.local/share:$HOME/.npm:$HOME/.pnpm-store:$HOME/.cargo/registry"

    # Enhanced zoxide aliases with fzf integration
    alias ,='zoxide query -i' # Interactive fzf jump
    alias za='zoxide add'      # Add current directory
    alias zr='zoxide remove'   # Remove directory from database
    alias zq='zoxide query'    # Query without jumping
    alias zl='zoxide query -l' # List all directories

    # Smart directory jumping with fzf
    alias j='zoxide query -i'
    alias jj='zoxide query -i'

    # Quick project navigation (zoxide -i = interactive fzf picker)
    # Note: 'dev' alias is defined in 03-aliases.zsh as 'cd ~/Projects && ls'
    alias work='zoxide query -i ~/Work'
    alias docs='zoxide query -i ~/Documents'
    alias dl='zoxide query -i ~/Downloads'
    alias conf='zoxide query -i ~/.config'

    alias projects='cd ~/Projects && ls'

    # Git repository navigation with fzf
    if (( $+commands[fzf] )); then
        # Find and jump to any git repository
        grepo() {
            local repo=$(find ~/Projects ~/Work ~/.config -name ".git" -type d 2>/dev/null | sed 's/\/.git//' | fzf --preview 'eza --tree --level=2 --icons {} 2>/dev/null || ls -la {}')
            if [ -n "$repo" ]; then
                cd "$repo" && zoxide add "$repo"
            fi
        }
        
        # Jump to recently used git repos
        alias repos='grepo'
    fi
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
# KEYBINDINGS
# =============================================================================
# Smart history search
autoload -U up-line-or-beginning-search down-line-or-beginning-search
if [[ -o interactive ]]; then
    zle -N up-line-or-beginning-search
    zle -N down-line-or-beginning-search
    bindkey "^[[A" up-line-or-beginning-search
    bindkey "^[[B" down-line-or-beginning-search
fi

# =============================================================================
# PROMPT SETUP
# =============================================================================
# Starship prompt (if available) - cached for performance
if (( $+commands[starship] )); then
    if typeset -f _cached_eval >/dev/null; then
        _cached_eval "starship" "starship init zsh"
    else
        eval "$(starship init zsh)"
    fi
fi

# =============================================================================
# FNM (Fast Node Manager) - Primary Node.js Version Manager
# =============================================================================
if (( $+commands[fnm] )); then
    export FNM_COREPACK_ENABLED=true
    
    # Use cached eval if available, otherwise run directly
    if typeset -f _cached_eval >/dev/null; then
        _cached_eval "fnm" "fnm env --use-on-cd"
    else
        eval "$(fnm env --use-on-cd)"
    fi

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

# =============================================================================
# GREPAI (Semantic Code Search)
# =============================================================================
if (( $+commands[grepai] )); then
    _grepai() {
        unfunction _grepai
        if typeset -f _cached_eval >/dev/null; then
            _cached_eval "grepai" "grepai completion zsh"
        else
            eval "$(grepai completion zsh)"
        fi
        _grepai "$@"
    }
    compdef _grepai grepai
fi
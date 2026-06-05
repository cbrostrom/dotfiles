# shellcheck shell=bash disable=SC1091
# =============================================================================
# PLUGIN MANAGEMENT — direct source, no plugin manager
# =============================================================================
# All plugins installed via brew or cloned once by modules/zsh/install.sh.
# Load order matters: autosuggestions before syntax highlighting.

_ZSH_PLUGINS_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/zsh/plugins"

# =============================================================================
# ZSH-AUTOSUGGESTIONS
# =============================================================================
for _f in \
    /opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh \
    /usr/local/share/zsh-autosuggestions/zsh-autosuggestions.zsh \
    /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh; do
    [[ -f "$_f" ]] && { source "$_f"; break; }
done
unset _f

# =============================================================================
# FZF-TAB — must load before syntax highlighting, after compinit
# =============================================================================
if [[ -f "$_ZSH_PLUGINS_DIR/fzf-tab/fzf-tab.plugin.zsh" ]]; then
    source "$_ZSH_PLUGINS_DIR/fzf-tab/fzf-tab.plugin.zsh"
fi

# =============================================================================
# ZSH-SYNTAX-HIGHLIGHTING — must be last plugin loaded
# =============================================================================
for _f in \
    /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh \
    /usr/local/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh \
    /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh; do
    [[ -f "$_f" ]] && { source "$_f"; break; }
done
unset _f

# =============================================================================
# FZF CONFIGURATION
# =============================================================================
export FZF_DEFAULT_OPTS='--height 40% --layout=reverse --border --preview "bat --style=numbers --color=always --line-range :500 {} 2>/dev/null || cat {} 2>/dev/null || tree -C {} 2>/dev/null"'
export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git --exclude node_modules --exclude .cache'
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_ALT_C_COMMAND='fd --type d --hidden --follow --exclude .git --exclude node_modules --exclude .cache'

if (( $+commands[fzf] )); then
    # fzf shell integration (keybindings + completion)
    for _fzf_shell in \
        /opt/homebrew/opt/fzf/shell \
        /usr/local/opt/fzf/shell \
        /usr/share/doc/fzf/examples; do
        if [[ -d "$_fzf_shell" ]]; then
            [[ -f "$_fzf_shell/key-bindings.zsh" ]] && source "$_fzf_shell/key-bindings.zsh"
            [[ -f "$_fzf_shell/completion.zsh" ]]   && source "$_fzf_shell/completion.zsh"
            break
        fi
    done
    unset _fzf_shell

    bindkey '^R' fzf-history-widget
    bindkey '^F' fzf-file-widget
    bindkey '^[c' fzf-cd-widget

    alias ff='fzf --preview "bat --style=numbers --color=always --line-range :500 {} 2>/dev/null || cat {} 2>/dev/null"'
fi

# =============================================================================
# FZF-TAB CONFIGURATION
# =============================================================================
if (( $+functions[enable-fzf-tab] )); then
    enable-fzf-tab
    zstyle ':fzf-tab:*' fzf-command fzf
    zstyle ':fzf-tab:*' fzf-flags --height=40% --border --preview-window=right:60%
    zstyle ':fzf-tab:complete:*:*' fzf-preview 'bat --style=numbers --color=always $realpath 2>/dev/null || ls -la $realpath 2>/dev/null'
    zstyle ':fzf-tab:complete:cd:*' fzf-preview 'eza --tree --icons --level=2 $realpath 2>/dev/null || ls -la $realpath'
    zstyle ':fzf-tab:complete:git-(add|diff|restore):*' fzf-preview 'git diff $word | delta 2>/dev/null || git diff $word'
fi

# =============================================================================
# COMPLETIONS
# =============================================================================
autoload -Uz compinit
# -C skips compaudit (security check) every time — saves ~50-100ms
# compaudit only matters if someone can write to your fpath dirs (unlikely)
compinit -C -d "${HOME}/.zcompdump"

# Local per-machine aliases (not tracked in git)
[[ -f "$HOME/.local-aliases" ]] && source "$HOME/.local-aliases"

zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'
zstyle ':completion:*' menu select
zstyle ':completion:*' accept-exact '*(N)'
zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path $HOME/.zsh_cache
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}
zstyle ':completion:*' group-name ''
zstyle ':completion:*' completer _expand _complete _correct _approximate

# =============================================================================
# KEYBINDINGS
# =============================================================================
autoload -U up-line-or-beginning-search down-line-or-beginning-search
if [[ -o interactive ]]; then
    zle -N up-line-or-beginning-search
    zle -N down-line-or-beginning-search
    bindkey "^[[A" up-line-or-beginning-search
    bindkey "^[[B" down-line-or-beginning-search
fi

# =============================================================================
# ZOXIDE
# =============================================================================
if (( $+commands[zoxide] )); then
    (( $+aliases[zi] )) && unalias zi
    if typeset -f _cached_eval >/dev/null; then
        _cached_eval "zoxide" "zoxide init zsh"
    else
        eval "$(zoxide init zsh)"
    fi
    export _ZO_FZF_OPTS="--height 40% --layout=reverse --border --preview 'eza --tree --icons --level=2 {} 2>/dev/null || tree -C {} 2>/dev/null'"
    export _ZO_ECHO=1
    export _ZO_EXCLUDE_DIRS="$HOME/.cache:$HOME/.local/share:$HOME/.npm:$HOME/.cargo/registry"
    alias ,='zoxide query -i'
    alias za='zoxide add'
    alias zr='zoxide remove'
    alias zq='zoxide query'
    alias zl='zoxide query -l'
    alias j='zoxide query -i'

    if (( $+commands[fzf] )); then
        grepo() {
            local repo
            repo=$(find ~/Projects ~/Work ~/.config -name ".git" -type d 2>/dev/null \
                | sed 's/\/.git//' \
                | fzf --preview 'eza --tree --level=2 --icons {} 2>/dev/null || ls -la {}')
            [[ -n "$repo" ]] && cd "$repo" && zoxide add "$repo"
        }
        alias repos='grepo'
    fi
fi

# =============================================================================
# STARSHIP PROMPT
# =============================================================================
if (( $+commands[starship] )); then
    if typeset -f _cached_eval >/dev/null; then
        _cached_eval "starship" "starship init zsh"
    else
        eval "$(starship init zsh)"
    fi
fi

# =============================================================================
# FNM (Fast Node Manager)
# =============================================================================
if (( $+commands[fnm] )); then
    export FNM_COREPACK_ENABLED=true
    if typeset -f _cached_eval >/dev/null; then
        _cached_eval "fnm" "fnm env --use-on-cd"
    else
        eval "$(fnm env --use-on-cd)"
    fi
    alias node16='fnm use 16'
    alias node18='fnm use 18'
    alias node20='fnm use 20'
    alias node22='fnm use 22'
    alias nodelts='fnm use lts-latest'
fi

unset _ZSH_PLUGINS_DIR


# Added by OrbStack: command-line tools and integration
# This won't be added again if you remove it.
source ~/.orbstack/shell/init.zsh 2>/dev/null || :

# fnm default node for login shells (pi-web LaunchAgents, etc.)
# (fnm env embeds a per-shell multishell path, so it is not cached.)
[[ -f "$HOME/dotfiles/zsh/zprofile-fnm.zsh" ]] && source "$HOME/dotfiles/zsh/zprofile-fnm.zsh"

# Hermes Agent — ensure ~/.local/bin is on PATH
export PATH="$HOME/.local/bin:$PATH"

# brew shellenv via the init cache (_cached_eval lives in 00-performance.zsh)
if ! typeset -f _cached_eval >/dev/null && [[ -f "$HOME/dotfiles/zsh/00-performance.zsh" ]]; then
    source "$HOME/dotfiles/zsh/00-performance.zsh"
fi
if typeset -f _cached_eval >/dev/null; then
    _cached_eval "brew-shellenv" "/opt/homebrew/bin/brew shellenv"
else
    eval "$(/opt/homebrew/bin/brew shellenv)"
fi

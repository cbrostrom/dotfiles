# =============================================================================
# .zshenv — sourced for ALL zsh invocations (interactive, login, scripts, cron)
# =============================================================================
# Keep this minimal: only PATH and locale that non-interactive jobs also need.
# Heavy init (plugins, prompts, completions) belongs in .zshrc.
# =============================================================================

# Locale — consistent rendering across SSH between mac/linuxbro/superbro/WSL
export LANG="${LANG:-en_US.UTF-8}"
export LC_ALL="${LC_ALL:-en_US.UTF-8}"

# Base PATH
typeset -U path PATH
path=(
    "$HOME/bin"
    "$HOME/.local/bin"
    "$HOME/.cargo/bin"
    $path
)

# Homebrew (macOS prefers /opt/homebrew on Apple Silicon)
if [[ -x /opt/homebrew/bin/brew ]]; then
    path=(/opt/homebrew/bin /opt/homebrew/sbin $path)
elif [[ -x /usr/local/bin/brew ]]; then
    path=(/usr/local/bin /usr/local/sbin $path)
fi

# Linuxbrew
[[ -d /home/linuxbrew/.linuxbrew/bin ]] && path=(/home/linuxbrew/.linuxbrew/bin /home/linuxbrew/.linuxbrew/sbin $path)

# Go
[[ -d "$HOME/go/bin" ]] && path=("$HOME/go/bin" $path)

# Bun
[[ -d "$HOME/.bun/bin" ]] && path=("$HOME/.bun/bin" $path)

# fnm
[[ -d "$HOME/.local/share/fnm" ]] && path=("$HOME/.local/share/fnm" $path)

export PATH

# Bitwarden-injected env vars (rbw module) — silent no-op if rbw not installed
[[ -r "$HOME/dotfiles/modules/rbw/env-secrets.zsh" ]] \
    && source "$HOME/dotfiles/modules/rbw/env-secrets.zsh"

# Pi global model (overrides project-local settings)
export PI_MODEL="github-copilot/claude-sonnet-5"

# OpenCode server override (headless only — allows git commit/push)
if [[ -z "${DISPLAY:-}" && -z "${WAYLAND_DISPLAY:-}" && -f "$HOME/.config/opencode/server.json" ]]; then
    export OPENCODE_CONFIG="$HOME/.config/opencode/server.json"
fi

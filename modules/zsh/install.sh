#!/usr/bin/env bash
# =============================================================================
# modules/zsh/install.sh — install zsh plugins (no plugin manager)
# =============================================================================
# Installs:
#   - zsh-autosuggestions    via brew (macOS) / apt (Debian)
#   - zsh-syntax-highlighting via brew (macOS) / apt (Debian)
#   - fzf-tab                via git clone → ~/.local/share/zsh/plugins/fzf-tab
#
# 02-plugins.zsh sources these directly — no zinit or other manager needed.
# =============================================================================
set -euo pipefail
. "$DOTFILES_DIR/modules/_lib/log.sh"
. "$DOTFILES_DIR/modules/_lib/platform.sh"

ZSH_PLUGINS_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/zsh/plugins"
mkdir -p "$ZSH_PLUGINS_DIR"

# -----------------------------------------------------------------------------
# brew-managed plugins (already in Brewfile — just verify)
# -----------------------------------------------------------------------------
if is_macos; then
    for pkg in zsh-autosuggestions zsh-syntax-highlighting fzf; do
        if has brew && ! brew list "$pkg" &>/dev/null; then
            log "installing $pkg via brew …"
            brew install "$pkg" || warn "failed to install $pkg"
        else
            ok "$pkg present"
        fi
    done
fi

# -----------------------------------------------------------------------------
# apt-managed plugins (Debian/Ubuntu/WSL)
# -----------------------------------------------------------------------------
if is_debian; then
    for pkg in zsh-autosuggestions zsh-syntax-highlighting fzf; do
        if ! dpkg -l "$pkg" &>/dev/null; then
            log "installing $pkg via apt …"
            sudo apt-get install -y "$pkg" || warn "failed to install $pkg"
        else
            ok "$pkg present"
        fi
    done
fi

# -----------------------------------------------------------------------------
# fzf-tab — not in brew/apt, clone once
# -----------------------------------------------------------------------------
FZF_TAB_DIR="$ZSH_PLUGINS_DIR/fzf-tab"
if [[ -d "$FZF_TAB_DIR/.git" ]]; then
    log "updating fzf-tab …"
    git -C "$FZF_TAB_DIR" pull --ff-only --quiet || warn "fzf-tab update failed (non-fatal)"
    ok "fzf-tab up to date"
else
    log "cloning fzf-tab → $FZF_TAB_DIR …"
    git clone --depth=1 https://github.com/Aloxaf/fzf-tab "$FZF_TAB_DIR" \
        || warn "fzf-tab clone failed — tab completion will fall back to default"
    ok "fzf-tab installed"
fi

# -----------------------------------------------------------------------------
# Remove zinit (no longer needed)
# -----------------------------------------------------------------------------
ZINIT_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/zinit"
if [[ -d "$ZINIT_DIR" ]]; then
    log "removing zinit (replaced by direct source) …"
    rm -rf "$ZINIT_DIR"
    ok "zinit removed"
fi

ok "zsh plugins ready — no plugin manager"

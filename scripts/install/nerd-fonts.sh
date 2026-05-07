#!/usr/bin/env bash
# =============================================================================
# scripts/install/nerd-fonts.sh — install JetBrains Mono Nerd Font
# =============================================================================
# Required by starship.toml + eza icons + Ghostty config.
# Idempotent: skips download if font already present.
# =============================================================================

set -euo pipefail

FONT_NAME="JetBrainsMono"
FONT_VERSION="${NERD_FONT_VERSION:-v3.2.1}"
URL="https://github.com/ryanoasis/nerd-fonts/releases/download/${FONT_VERSION}/${FONT_NAME}.zip"

log() { printf "[fonts] %s\n" "$*"; }

install_manual() {
    local font_dir="$1"
    mkdir -p "$font_dir"
    local tmp
    tmp="$(mktemp -d)"
    log "Downloading $FONT_NAME $FONT_VERSION → $tmp"
    curl -fsSL -o "$tmp/font.zip" "$URL"
    unzip -q -o "$tmp/font.zip" -d "$font_dir/$FONT_NAME"
    rm -rf "$tmp"
    command -v fc-cache >/dev/null 2>&1 && fc-cache -fv >/dev/null 2>&1 || true
    log "Installed to $font_dir/$FONT_NAME"
}

case "$(uname -s)" in
    Darwin)
        if command -v brew >/dev/null 2>&1; then
            log "Installing via Homebrew…"
            brew install --cask font-jetbrains-mono-nerd-font || true
        else
            install_manual "$HOME/Library/Fonts"
        fi
        ;;
    Linux)
        if fc-list 2>/dev/null | grep -qi "jetbrainsmono nerd"; then
            log "JetBrainsMono Nerd Font already installed."
            exit 0
        fi
        install_manual "$HOME/.local/share/fonts"
        ;;
    *)
        echo "Unsupported OS for font install." >&2
        exit 1
        ;;
esac

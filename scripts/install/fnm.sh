#!/usr/bin/env bash
# Cross-platform fnm (Fast Node Manager) bootstrap. Idempotent.
# Installs the fnm binary if missing, then ensures a default Node version.
# macOS provides fnm via the Brewfile; Linux installs to ~/.local/bin.
set -euo pipefail

FNM_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/fnm"
BIN_DIR="$HOME/.local/bin"
OS="$(uname -s)"
ARCH="$(uname -m)"
case "$ARCH" in
    x86_64) FNM_ARCH="x64" ;;
    aarch64 | arm64) FNM_ARCH="arm64" ;;
    *)
        printf '[fnm] error: unsupported architecture: %s\n' "$ARCH" >&2
        exit 1
        ;;
esac
if [[ "$OS" != "Darwin" && "$OS" != "Linux" ]]; then
    printf '[fnm] error: unsupported OS: %s\n' "$OS" >&2
    exit 1
fi

has() { command -v "$1" >/dev/null 2>&1; }

# Pick up an existing fnm installed on the XDG data path.
if ! has fnm && [[ -x "$FNM_DIR/fnm" ]]; then
    export PATH="$FNM_DIR:$PATH"
fi

if ! has fnm; then
    if has brew; then
        printf '[fnm] installing via Homebrew\n'
        brew install fnm
    else
        mkdir -p "$BIN_DIR"
        printf '[fnm] installing binary to %s/fnm\n' "$BIN_DIR"
        url="https://github.com/Schniz/fnm/releases/latest/download/fnm-linux.zip"
        [[ "$OS" == "Darwin" ]] && url="https://github.com/Schniz/fnm/releases/latest/download/fnm-macos.zip"
        tmp="$(mktemp -d)"
        trap 'rm -rf "$tmp"' EXIT
        curl -fsSL "$url" -o "$tmp/fnm.zip"
        unzip -o -q "$tmp/fnm.zip" -d "$tmp"
        install -m 0755 "$tmp/fnm" "$BIN_DIR/fnm"
        export PATH="$BIN_DIR:$PATH"
    fi
fi

# Activate fnm's PATH hooks for this non-interactive shell.
eval "$(fnm env --shell bash)"

if has node; then
    printf '[fnm] node already present: %s\n' "$(node --version)"
else
    printf '[fnm] installing latest Node.js\n'
    latest="$(fnm ls-remote | tail -1)"
    fnm install "$latest"
    fnm default "$latest"
    # Re-apply env so the freshly installed default is on PATH now.
    eval "$(fnm env --shell bash)"
fi

printf '[fnm] fnm=%s node=%s npm=%s\n' \
    "$(fnm --version)" \
    "$(node --version 2>/dev/null || echo missing)" \
    "$(npm --version 2>/dev/null || echo missing)"

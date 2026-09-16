#!/usr/bin/env bash
# =============================================================================
# scripts/install/rtk.sh — install the rtk CLI from GitHub releases
# =============================================================================
# rtk (https://github.com/rtk-ai/rtk) — LLM token-saving command proxy.
# macOS: prefer `brew install rtk` (homebrew-core); this script covers Linux
# and any host without brew by downloading the release tarball.
#
# Idempotent: skips when the requested version is already installed;
# set RTK_VERSION=latest (default) or a tag like v0.49.0 to pin.
# =============================================================================

set -euo pipefail

BIN_DIR="$HOME/.local/bin"
TARGET="$BIN_DIR/rtk"
VERSION="${RTK_VERSION:-latest}"

log() { printf '[rtk-install] %s\n' "$*"; }
err() { printf '[rtk-install] error: %s\n' "$*" >&2; }

# macOS with brew: nothing to do here; homebrew owns the binary.
if [[ "$(uname -s)" == "Darwin" ]] && command -v brew >/dev/null 2>&1; then
    if command -v rtk >/dev/null 2>&1; then
        log "rtk already managed by brew ($(rtk --version 2>/dev/null || echo '?')); skipping"
    else
        log "installing via brew"
        brew install rtk
    fi
    exit 0
fi

case "$(uname -s)-$(uname -m)" in
    Linux-x86_64) asset="rtk-x86_64-unknown-linux-musl.tar.gz" ;;
    Linux-aarch64) asset="rtk-aarch64-unknown-linux-gnu.tar.gz" ;;
    Darwin-arm64) asset="rtk-aarch64-apple-darwin.tar.gz" ;;
    Darwin-x86_64) asset="rtk-x86_64-apple-darwin.tar.gz" ;;
    *)
        err "unsupported platform: $(uname -s)-$(uname -m)"
        exit 1
        ;;
esac

if [[ "$VERSION" == "latest" ]]; then
    VERSION="$(curl -fsSL https://api.github.com/repos/rtk-ai/rtk/releases/latest |
        grep -o '"tag_name": *"[^"]*"' | cut -d'"' -f4)"
    [[ -n "$VERSION" ]] || { err "could not resolve latest rtk release"; exit 1; }
fi

if [[ -x "$TARGET" ]] && "$TARGET" --version 2>/dev/null | grep -q "$VERSION"; then
    log "rtk $VERSION already installed"
    exit 0
fi

url="https://github.com/rtk-ai/rtk/releases/download/$VERSION/$asset"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

log "downloading $url"
curl -fsSL "$url" -o "$tmp/rtk.tar.gz"

tar -xzf "$tmp/rtk.tar.gz" -C "$tmp"
binary="$(find "$tmp" -type f -name rtk | head -1)"
[[ -n "$binary" ]] || { err "rtk binary not found in tarball"; exit 1; }

mkdir -p "$BIN_DIR"
install -m 755 "$binary" "$TARGET"
log "installed: $TARGET ($("$TARGET" --version 2>/dev/null || echo '?'))"

#!/usr/bin/env bash
# =============================================================================
# scripts/install/zellij.sh — cross-platform zellij installer
# =============================================================================
# macOS  : brew install zellij           (idempotent, skipped if present)
# Debian : GitHub release tarball → /usr/local/bin/zellij
#          (zellij is NOT in Debian 12 apt repo)
#
# Idempotent: skips download if installed version >= ZELLIJ_VERSION
# Override:   ZELLIJ_VERSION=v0.43.0 ./zellij.sh
# =============================================================================

set -euo pipefail

ZELLIJ_VERSION="${ZELLIJ_VERSION:-}"   # empty = fetch latest
PINNED_FALLBACK="v0.43.1"              # used if GH API unreachable

log()  { printf "[zellij] %s\n" "$*"; }
warn() { printf "[zellij] warn: %s\n" "$*" >&2; }

current_version() {
    command -v zellij >/dev/null 2>&1 || return 1
    zellij --version 2>/dev/null | awk '{print "v"$2}'
}

resolve_latest() {
    local tag
    tag="$(curl -fsSL https://api.github.com/repos/zellij-org/zellij/releases/latest 2>/dev/null \
        | grep -E '"tag_name"' | head -1 | cut -d'"' -f4)"
    if [[ -z "$tag" ]]; then
        warn "GitHub API unreachable, falling back to pinned $PINNED_FALLBACK"
        echo "$PINNED_FALLBACK"
    else
        echo "$tag"
    fi
}

install_macos() {
    if ! command -v brew >/dev/null 2>&1; then
        warn "Homebrew missing — install from https://brew.sh"
        return 1
    fi
    if brew list --formula zellij >/dev/null 2>&1; then
        log "already installed via brew ($(zellij --version))"
        brew upgrade zellij 2>/dev/null || true
    else
        log "installing via brew …"
        brew install zellij
    fi
}

install_debian() {
    [[ -z "$ZELLIJ_VERSION" ]] && ZELLIJ_VERSION="$(resolve_latest)"

    local cur
    cur="$(current_version || true)"
    if [[ -n "$cur" && "$cur" == "$ZELLIJ_VERSION" ]]; then
        log "already at $cur — skip"
        return 0
    fi

    local arch asset
    case "$(uname -m)" in
        x86_64|amd64)   arch="x86_64-unknown-linux-musl" ;;
        aarch64|arm64)  arch="aarch64-unknown-linux-musl" ;;
        *) warn "unsupported arch: $(uname -m)"; return 1 ;;
    esac
    asset="zellij-${arch}.tar.gz"
    local url="https://github.com/zellij-org/zellij/releases/download/${ZELLIJ_VERSION}/${asset}"

    local tmp
    tmp="$(mktemp -d)"
    log "downloading $ZELLIJ_VERSION ($arch) …"
    if ! curl -fsSL -o "$tmp/zellij.tgz" "$url"; then
        warn "download failed: $url"
        rm -rf "$tmp"
        return 1
    fi
    tar -xzf "$tmp/zellij.tgz" -C "$tmp"
    log "installing to /usr/local/bin (sudo) …"
    sudo install -m 0755 "$tmp/zellij" /usr/local/bin/zellij
    rm -rf "$tmp"
    log "installed: $(zellij --version)"
}

install_plugins() {
    local plugin_dir="$HOME/.config/zellij/plugins"
    mkdir -p "$plugin_dir"

    local zjs="$plugin_dir/zjstatus.wasm"
    if [[ -f "$zjs" ]]; then
        log "zjstatus.wasm already present — skip"
    else
        log "downloading zjstatus.wasm …"
        if curl -fsSL -o "$zjs" \
            https://github.com/dj95/zjstatus/releases/latest/download/zjstatus.wasm; then
            log "zjstatus installed: $(du -h "$zjs" | cut -f1)"
        else
            warn "zjstatus download failed (status-bar layouts will fail)"
            rm -f "$zjs"
        fi
    fi
}

case "$(uname -s)" in
    Darwin) install_macos ;;
    Linux)
        if [[ -f /etc/debian_version ]]; then
            install_debian
        else
            warn "non-Debian Linux — install zellij manually or via your package manager"
            exit 1
        fi
        ;;
    *)  warn "unsupported OS: $(uname -s)"; exit 1 ;;
esac

install_plugins

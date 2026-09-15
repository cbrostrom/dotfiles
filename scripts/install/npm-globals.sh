#!/usr/bin/env bash
# Cross-platform npm global installs (agent providers that Stow cannot supply).
# Idempotent: skips anything already on PATH. Requires node/npm.
set -euo pipefail

log() { printf '[npm-globals] %s\n' "$*"; }

if ! command -v npm >/dev/null 2>&1; then
    printf '[npm-globals] error: npm not found; install Node.js first\n' >&2
    exit 1
fi

has() { command -v "$1" >/dev/null 2>&1; }

install_global() {
    local pkg="$1" bin="$2"
    if has "$bin"; then
        log "$bin already installed ($("$bin" --version 2>/dev/null || echo '?'))"
        return 0
    fi
    log "installing $pkg"
    npm install -g "$pkg"
}

install_global "@earendil-works/pi-coding-agent" "pi"
install_global "@getpaseo/cli" "paseo"

log "pi=$(pi --version 2>/dev/null || echo missing) paseo=$(paseo --version 2>/dev/null || echo missing)"

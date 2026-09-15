#!/usr/bin/env bash
# Cross-platform npm global installs (agent providers that Stow cannot supply).
# Idempotent: skips anything already on PATH. Requires node/npm.
set -euo pipefail

log() { printf '[npm-globals] %s\n' "$*"; }

activate_fnm() {
    # fnm.sh bootstraps node in its own process; exports do not propagate, so
    # derive the PATH here in this shell after the first-time install.
    if command -v fnm >/dev/null 2>&1; then
        # shellcheck disable=SC2046
        eval "$("$(command -v fnm)" env --shell bash 2>/dev/null)"
    fi
    export PATH="$HOME/.local/bin:${XDG_DATA_HOME:-$HOME/.local/share}/fnm:$PATH"
}

if ! command -v npm >/dev/null 2>&1; then
    printf '[npm-globals] npm not found; bootstrapping fnm + Node.js
'
    activate_fnm
    "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/fnm.sh"
    activate_fnm
fi

if ! command -v npm >/dev/null 2>&1; then
    printf '[npm-globals] error: npm still not found; run scripts/install/fnm.sh and check output\n' >&2
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

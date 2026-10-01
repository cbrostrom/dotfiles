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

# One prefix on every host; ~/.local/bin/{pi,paseo} are stow shims into it, so a
# binary on PATH proves nothing — check the package directory instead.
PREFIX="${NPM_CONFIG_PREFIX:-$HOME/.npm-global}"

install_global() {
    local pkg="$1"
    if [[ -f "$PREFIX/lib/node_modules/$pkg/package.json" ]]; then
        log "$pkg already installed ($(jq -r .version "$PREFIX/lib/node_modules/$pkg/package.json"))"
        return 0
    fi
    log "installing $pkg into $PREFIX"
    npm install -g --prefix "$PREFIX" "$pkg"
}

install_global "@earendil-works/pi-coding-agent"
install_global "@getpaseo/cli"

log "pi=$(pi --version 2>/dev/null || echo missing) paseo=$(paseo --version 2>/dev/null || echo missing)"

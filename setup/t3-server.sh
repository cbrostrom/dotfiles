#!/usr/bin/env bash
# Run T3 Code as a headless background service on a Linux fleet host.
#
#   DOTFILES_FLEET_HOST=cloudbro ./setup/t3-server.sh
#
# Installs the t3 CLI from npm and installs the user service bound to loopback.
# Tailscale Serve publishes it over HTTPS on the tailnet, and T3 Connect (the
# relay) tunnels to the same loopback port. Tailscale Serve needs a one-time
# `sudo tailscale set --operator=$USER`; the relay needs `t3 connect link
# --headless`. Pair from the Mac with `t3 pair` on the host.
# Restarts the service only when service.env changes, so fleet updates do not
# kill running agent sessions.

set -euo pipefail

DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
. "$DOTFILES_DIR/setup/lib.sh"
activate_fnm

[[ "$(uname -s)" == "Linux" ]] || die "t3-server: Linux only"

T3_HOME="${T3CODE_HOME:-$HOME/.t3}"
T3_PORT="${T3_PORT:-3773}"

# Same prefix as zsh/01-environment.zsh so `t3` is on PATH in interactive shells.
npm_prefix="${NPM_CONFIG_PREFIX:-$HOME/.npm-global}"
export PATH="$npm_prefix/bin:$T3_HOME/bin:$PATH"
if [[ ! -x "$npm_prefix/bin/t3" ]]; then
    log "install t3 CLI (npm, $npm_prefix)"
    npm install -g --prefix "$npm_prefix" t3 >/dev/null
fi
command -v t3 >/dev/null 2>&1 || die "t3-server: t3 not on PATH after install"

mkdir -p "$T3_HOME"
env_file="$T3_HOME/service.env"
desired="T3CODE_HOST=127.0.0.1
T3CODE_PORT=$T3_PORT
T3CODE_TAILSCALE_SERVE=true"
env_changed=no
if [[ ! -f "$env_file" ]] || [[ "$(cat "$env_file")" != "$desired" ]]; then
    printf '%s\n' "$desired" >"$env_file"
    env_changed=yes
fi

if t3 service status | grep -q 'Status: not installed'; then
    log "install T3 service (127.0.0.1:$T3_PORT + Tailscale Serve)"
    t3 service install
    ok "T3 service installed; pair with: t3 pair"
elif [[ "$env_changed" == yes ]]; then
    t3 service restart
    ok "T3 service restarted on 127.0.0.1:$T3_PORT + Tailscale Serve"
else
    ok "T3 service already running on 127.0.0.1:$T3_PORT + Tailscale Serve"
fi

"$DOTFILES_DIR/setup/t3.sh"

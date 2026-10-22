#!/usr/bin/env bash
# Run T3 Code as a headless background service on a Linux fleet host.
#
#   DOTFILES_FLEET_HOST=cloudbro ./setup/t3-server.sh
#
# Installs the t3 CLI from npm, binds the server to the host's tailnet address
# from config/fleet-hosts.conf (plain HTTP on T3_PORT, tailnet only), and
# installs the user service. Pair from the Mac with `t3 pair` on the host.
# Restarts the service only when service.env changes, so fleet updates do not
# kill running agent sessions.

set -euo pipefail

DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
. "$DOTFILES_DIR/setup/lib.sh"
activate_fnm

[[ "$(uname -s)" == "Linux" ]] || die "t3-server: Linux only"

T3_HOME="${T3CODE_HOME:-$HOME/.t3}"
T3_PORT="${T3_PORT:-3773}"
host="$(fleet_host_name)"
address="$(fleet_field "$host" 1)" || die "t3-server: $host is not in FLEET_SSH"

if ! command -v t3 >/dev/null 2>&1 && [[ ! -x "$T3_HOME/bin/t3" ]]; then
    log "install t3 CLI (npm)"
    npm install -g t3 >/dev/null
fi
export PATH="$T3_HOME/bin:$PATH"
command -v t3 >/dev/null 2>&1 || die "t3-server: t3 not on PATH after install"

mkdir -p "$T3_HOME"
env_file="$T3_HOME/service.env"
desired="T3CODE_HOST=$address
T3CODE_PORT=$T3_PORT"
env_changed=no
if [[ ! -f "$env_file" ]] || [[ "$(cat "$env_file")" != "$desired" ]]; then
    printf '%s\n' "$desired" >"$env_file"
    env_changed=yes
fi

if t3 service status | grep -q 'Status: not installed'; then
    log "install T3 service ($address:$T3_PORT)"
    t3 service install
    ok "T3 service installed; pair with: t3 pair"
elif [[ "$env_changed" == yes ]]; then
    t3 service restart
    ok "T3 service restarted on $address:$T3_PORT"
else
    ok "T3 service already running on $address:$T3_PORT"
fi

"$DOTFILES_DIR/setup/t3.sh"

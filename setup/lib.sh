#!/usr/bin/env bash

log() { printf '[dotfiles] %s\n' "$*"; }
info() { log "$@"; }
ok() { printf '[dotfiles] ok: %s\n' "$*"; }
skip() { printf '[dotfiles] skip: %s\n' "$*"; }
warn() { printf '[dotfiles] warning: %s\n' "$*" >&2; }
err() { printf '[dotfiles] error: %s\n' "$*" >&2; }
die() {
    printf '[dotfiles] error: %s\n' "$*" >&2
    exit 1
}

# Activate fnm-managed Node (paseo/pi live under its node-versions PATH).
# Call before invoking node-backed CLIs from scripts that inherit a bare login
# PATH (fresh hosts; exports of sibling processes do not propagate).
activate_fnm() {
    if command -v fnm >/dev/null 2>&1; then
        # shellcheck disable=SC2046
        eval "$("$(command -v fnm)" env --shell bash 2>/dev/null)"
    fi
    export PATH="$HOME/.local/bin:${XDG_DATA_HOME:-$HOME/.local/share}/fnm:$PATH"
}

# Fleet host name for this machine: DOTFILES_FLEET_HOST, else short hostname.
fleet_host_name() {
    local name="${DOTFILES_FLEET_HOST:-$(hostname -s)}"
    printf '%s\n' "$name" | tr '[:upper:]' '[:lower:]'
}

# fleet_field <host> <index>: print a FLEET_SSH column (0=name, 1=address, 7=paseo).
fleet_field() {
    local entry fields
    # shellcheck source=../config/fleet-hosts.conf
    . "${DOTFILES_DIR:?}/config/fleet-hosts.conf"
    for entry in "${FLEET_SSH[@]}"; do
        IFS='|' read -r -a fields <<<"$entry"
        if [[ "${fields[0]}" == "$1" ]]; then
            printf '%s\n' "${fields[$2]}"
            return 0
        fi
    done
    return 1
}

#!/usr/bin/env bash
# Locate the canonical pi install (same rules as the ~/.local/bin/pi shim).

PI_NPM_PREFIX="${NPM_CONFIG_PREFIX:-$HOME/.npm-global}"
PI_PACKAGE="@earendil-works/pi-coding-agent"

pi_fnm_root() {
    local root="${FNM_DIR:-$HOME/Library/Application Support/fnm}"
    [[ -d "$root/node-versions" ]] || root="${XDG_DATA_HOME:-$HOME/.local/share}/fnm"
    printf '%s\n' "$root"
}

# Package dirs of pi copies living inside fnm node versions (legacy layout).
pi_fnm_copies() {
    local d
    for d in "$(pi_fnm_root)"/node-versions/v*/installation/lib/node_modules/$PI_PACKAGE; do
        [[ -f "$d/package.json" ]] && printf '%s\n' "$d"
    done
    return 0
}

pi_pkg_dir() {
    local canonical="$PI_NPM_PREFIX/lib/node_modules/$PI_PACKAGE"
    if [[ -f "$canonical/package.json" ]]; then
        printf '%s\n' "$canonical"
        return 0
    fi
    local last
    last="$(pi_fnm_copies | tail -n 1)"
    [[ -n "$last" ]] || return 1
    printf '%s\n' "$last"
}

#!/usr/bin/env bash
# Shared resolution: Pi-Bolt (default), PiG, managed pi.dev, npm fallback.

PI_NPM_PREFIX="${NPM_CONFIG_PREFIX:-$HOME/.npm-global}"
PI_PACKAGE="@earendil-works/pi-coding-agent"
PIBOLT_INSTALL="${PIBOLT_INSTALL:-$HOME/.pi-bolt}"
PI_MANAGED_MARKER="${PI_MANAGED_MARKER:-$HOME/.pi/agent/install/managed-install.json}"
PI_MANAGED_BIN="${PI_MANAGED_BIN:-$HOME/.pi/agent/bin/pi}"
PI_AGENT_DIR="${PI_AGENT_DIR:-$HOME/.pi/agent}"

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

pi_npm_prepare_path() {
    local fnm_root default_node resolved
    fnm_root="$(pi_fnm_root)"
    default_node="$(readlink "$fnm_root/aliases/default" 2>/dev/null || true)"
    [[ -d "$default_node/bin" ]] && export PATH="$default_node/bin:$PATH"
}

# Pi-Bolt macOS launcher (or installer symlink); empty if not installed.
pi_bolt_launcher() {
    local bin d
    bin="$(command -v pi-bolt 2>/dev/null || true)"
    if [[ -n "$bin" && -x "$bin" ]]; then
        printf '%s\n' "$bin"
        return 0
    fi
    for d in "$PIBOLT_INSTALL"/pi-bolt-*/pi; do
        if [[ -x "$d" ]]; then
            printf '%s\n' "$d"
            return 0
        fi
    done
    return 1
}

pi_managed_installed() {
    [[ -f "$PI_MANAGED_MARKER" && -x "$PI_MANAGED_BIN" ]]
}

pi_managed_bin() {
    if pi_managed_installed; then
        printf '%s\n' "$PI_MANAGED_BIN"
        return 0
    fi
    return 1
}

pi_pig_bin() {
    local bin
    bin="$(command -v pig 2>/dev/null || true)"
    if [[ -n "$bin" && -x "$bin" ]]; then
        printf '%s\n' "$bin"
        return 0
    fi
    return 1
}

pi_pig_env() {
    export PIG_USE_PI_DIRS=1
    export PIG_CODING_AGENT_DIR="${PIG_CODING_AGENT_DIR:-$PI_AGENT_DIR}"
}

# npm | bolt | managed | pig
# auto: bolt → managed → npm; set PI_USE_PIG=1 to prefer PiG in auto.
pi_backend() {
    case "${PI_BACKEND:-auto}" in
        npm) printf 'npm\n' ;;
        bolt) printf 'bolt\n' ;;
        managed) printf 'managed\n' ;;
        pig) printf 'pig\n' ;;
        auto)
            if [[ "${PI_USE_PIG:-0}" == 1 ]] && pi_pig_bin >/dev/null; then
                printf 'pig\n'
            elif pi_bolt_launcher >/dev/null; then
                printf 'bolt\n'
            elif pi_managed_installed; then
                printf 'managed\n'
            else
                printf 'npm\n'
            fi
            ;;
        *)
            printf 'npm\n'
            ;;
    esac
}

pi_npm_bin() {
    pi_npm_prepare_path
    local npm_pi="$PI_NPM_PREFIX/bin/pi"
    if [[ -e "$npm_pi" ]]; then
        if [[ ! -L "$npm_pi" ]] || [[ "$(readlink "$npm_pi" 2>/dev/null)" != *"/.local/bin/pi" ]]; then
            printf '%s\n' "$npm_pi"
            return 0
        fi
    fi
    local cli="$PI_NPM_PREFIX/lib/node_modules/$PI_PACKAGE/dist/bundle/cli.js"
    if [[ -f "$cli" ]]; then
        printf '%s\n' "$cli"
        return 0
    fi
    local d resolved=""
    for d in "$(pi_fnm_root)"/node-versions/v*/installation; do
        [[ -x "$d/bin/pi" ]] && resolved="$d/bin/pi"
    done
    [[ -n "$resolved" ]] || return 1
    printf '%s\n' "$resolved"
}

pi_npm_exec() {
    local bin
    pi_npm_prepare_path
    if bin="$(pi_npm_bin)"; then
        exec "$bin" "$@"
    fi
    printf 'pi-npm: not found — run: ~/dotfiles/scripts/pi-doctor.sh --fix\n' >&2
    exit 127
}

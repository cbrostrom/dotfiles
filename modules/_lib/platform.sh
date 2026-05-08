#!/usr/bin/env bash
# Platform + profile detection for the module system.
#
# Platforms (mutually exclusive): macos, wsl, linux
#   - macos: Darwin
#   - wsl:   Linux running under WSL2 (Windows kernel)
#   - linux: Linux not under WSL
#
# Profiles (orthogonal to platform):
#   - desktop-full:    GUI workstation (mac, linuxbro)
#   - server-headless: VPS, no DISPLAY
#   - wsl:             WSL2 (TUI only; fonts/GUI go via Windows)
#
# A module may declare BOTH supported platforms AND supported profiles;
# both must match for it to run.

if [[ "${_DOTFILES_PLATFORM_LOADED:-}" == "1" ]]; then
    return 0 2>/dev/null || true
fi
_DOTFILES_PLATFORM_LOADED=1

is_macos()   { [[ "$(uname -s)" == "Darwin" ]]; }
is_linux()   { [[ "$(uname -s)" == "Linux" ]]; }
is_wsl()     { is_linux && { [[ -n "${WSL_DISTRO_NAME:-}" ]] || grep -qiE '(microsoft|wsl)' /proc/version 2>/dev/null; }; }
is_native_linux() { is_linux && ! is_wsl; }
is_debian()  { is_linux && [[ -f /etc/debian_version ]]; }
is_arch()    { is_linux && [[ -f /etc/arch-release ]]; }
is_fedora()  { is_linux && [[ -f /etc/fedora-release ]]; }
has()        { command -v "$1" >/dev/null 2>&1; }

# Echo the current platform tag (macos | wsl | linux).
platform_tag() {
    if is_macos; then echo "macos"
    elif is_wsl; then echo "wsl"
    else echo "linux"
    fi
}

# Echo the current profile (desktop-full | server-headless | wsl).
# Order: explicit env > ~/.local-config > heuristic.
profile_tag() {
    if [[ -n "${PROFILE:-}" ]]; then
        echo "$PROFILE"
        return
    fi
    if [[ -f "$HOME/.local-config" ]]; then
        local p
        p="$(grep -E '^PROFILE=' "$HOME/.local-config" 2>/dev/null \
             | head -1 | cut -d= -f2 | tr -d '"' | tr -d "'")"
        if [[ -n "$p" ]]; then
            echo "$p"
            return
        fi
    fi
    if is_wsl; then echo "wsl"
    elif is_macos; then echo "desktop-full"
    elif [[ -z "${DISPLAY:-}" && -z "${WAYLAND_DISPLAY:-}" ]]; then echo "server-headless"
    else echo "desktop-full"
    fi
}

# Returns 0 if the current platform is in the space-separated list of supported platforms.
# Empty list means "all platforms supported".
# Special token "all" also means all.
platform_matches() {
    local supported="$1"
    local current
    current="$(platform_tag)"
    [[ -z "$supported" || "$supported" == "all" ]] && return 0
    local p
    for p in $supported; do
        [[ "$p" == "all" ]] && return 0
        [[ "$p" == "$current" ]] && return 0
    done
    return 1
}

# Returns 0 if the current profile is in the space-separated list of supported profiles.
# Empty list means "all profiles supported".
profile_matches() {
    local supported="$1"
    local current
    current="$(profile_tag)"
    [[ -z "$supported" || "$supported" == "all" ]] && return 0
    local p
    for p in $supported; do
        [[ "$p" == "all" ]] && return 0
        [[ "$p" == "$current" ]] && return 0
    done
    return 1
}

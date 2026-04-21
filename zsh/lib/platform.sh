# =============================================================================
# PLATFORM HELPERS — used across all zsh modules and bootstrap.sh
# =============================================================================
# Source this file early. Provides:
#   is_macos / is_linux / is_wsl / is_debian        — boolean OS predicates
#   has <cmd>                                        — silent command-existence check
#   cache_eval <name> <init-cmd>                     — cached `eval` for slow init
#   profile                                          — desktop-full | server-headless | wsl
#   hostname_short                                   — `hostname -s` with sane fallback
# =============================================================================

is_macos()  { [[ "$(uname -s)" == "Darwin" ]]; }
is_linux()  { [[ "$(uname -s)" == "Linux"  ]]; }
is_wsl()    { is_linux && { [[ -n "$WSL_DISTRO_NAME" ]] || grep -qiE '(microsoft|wsl)' /proc/version 2>/dev/null; }; }
is_debian() { is_linux && [[ -f /etc/debian_version ]]; }

has() { command -v "$1" >/dev/null 2>&1; }

# cache_eval <name> <init-command>
# Caches stdout of <init-command> to ~/.cache/zsh/init/<name>.zsh and sources it.
# Cache TTL is 24h (refreshed via mtime check).
cache_eval() {
    local name="$1" cmd="$2"
    local dir="$HOME/.cache/zsh/init"
    local file="$dir/${name}.zsh"
    mkdir -p "$dir"
    if [[ ! -f "$file" ]] || [[ -n "$(find "$file" -mtime +1 2>/dev/null)" ]]; then
        eval "$cmd" > "$file" 2>/dev/null
    fi
    if [[ -s "$file" ]]; then
        source "$file"
    else
        eval "$cmd"
    fi
}

hostname_short() {
    local h
    h="$(hostname -s 2>/dev/null)" || h="$(hostname 2>/dev/null | cut -d. -f1)"
    echo "${h:-unknown}"
}

# profile: desktop-full | server-headless | wsl
# Order: $PROFILE env > ~/.local-config PROFILE= > heuristic
profile() {
    if [[ -n "$PROFILE" ]]; then
        echo "$PROFILE"
        return
    fi
    if [[ -f "$HOME/.local-config" ]]; then
        local p
        p="$(grep -E '^PROFILE=' "$HOME/.local-config" 2>/dev/null | head -1 | cut -d= -f2 | tr -d '"' | tr -d "'")"
        if [[ -n "$p" ]]; then
            echo "$p"
            return
        fi
    fi
    if is_wsl; then
        echo "wsl"
    elif [[ -z "$DISPLAY" && -z "$WAYLAND_DISPLAY" ]] && ! is_macos; then
        echo "server-headless"
    else
        echo "desktop-full"
    fi
}

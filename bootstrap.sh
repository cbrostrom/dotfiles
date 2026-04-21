#!/usr/bin/env bash
# =============================================================================
# bootstrap.sh — single entrypoint for provisioning a machine from dotfiles
# =============================================================================
# Idempotent. Detects OS + profile, installs packages, creates symlinks,
# verifies result. Designed to be safe to re-run.
#
# Usage:
#   ./bootstrap.sh                  # full bootstrap (detect everything)
#   ./bootstrap.sh --link-only      # only (re)create symlinks
#   ./bootstrap.sh --packages-only  # only install packages
#   ./bootstrap.sh --doctor         # diagnostic only, no changes
#   ./bootstrap.sh --profile=server-headless   # override profile
#
# Profiles:
#   desktop-full    — mac, linuxbro (GUI tools, fonts, Cursor)
#   server-headless — superbro VPS  (no GUI, security stack)
#   wsl             — WSL2 on monsterbro (TUI + Windows interop)
# =============================================================================

set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export DOTFILES_DIR

# Source platform helpers (zsh-flavored, but compatible bash subset)
# We re-implement minimally here since bootstrap.sh runs under bash.
is_macos()  { [[ "$(uname -s)" == "Darwin" ]]; }
is_linux()  { [[ "$(uname -s)" == "Linux"  ]]; }
is_wsl()    { is_linux && { [[ -n "${WSL_DISTRO_NAME:-}" ]] || grep -qiE '(microsoft|wsl)' /proc/version 2>/dev/null; }; }
is_debian() { is_linux && [[ -f /etc/debian_version ]]; }
has() { command -v "$1" >/dev/null 2>&1; }

# Color output
if [[ -t 1 ]]; then
    BLUE='\033[0;34m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
else
    BLUE=''; GREEN=''; YELLOW=''; RED=''; NC=''
fi
log()    { printf "${BLUE}[bootstrap]${NC} %s\n" "$*"; }
ok()     { printf "${GREEN}[ ok ]${NC} %s\n" "$*"; }
warn()   { printf "${YELLOW}[warn]${NC} %s\n" "$*"; }
err()    { printf "${RED}[err ]${NC} %s\n" "$*" >&2; }

# -----------------------------------------------------------------------------
# Profile detection
# -----------------------------------------------------------------------------
detect_profile() {
    local p=""
    for arg in "$@"; do
        case "$arg" in
            --profile=*) p="${arg#--profile=}";;
        esac
    done
    if [[ -z "$p" && -n "${PROFILE:-}" ]]; then p="$PROFILE"; fi
    if [[ -z "$p" && -f "$HOME/.local-config" ]]; then
        p="$(grep -E '^PROFILE=' "$HOME/.local-config" 2>/dev/null | head -1 | cut -d= -f2 | tr -d '"' | tr -d "'")"
    fi
    if [[ -z "$p" ]]; then
        if is_wsl; then p="wsl"
        elif is_macos; then p="desktop-full"
        elif [[ -z "${DISPLAY:-}" && -z "${WAYLAND_DISPLAY:-}" ]]; then p="server-headless"
        else p="desktop-full"
        fi
    fi
    echo "$p"
}

# -----------------------------------------------------------------------------
# Package install
# -----------------------------------------------------------------------------
install_packages() {
    local profile="$1"
    if is_macos; then
        if ! has brew; then
            warn "Homebrew not installed. Install from https://brew.sh, then re-run."
            return 1
        fi
        if [[ -f "$DOTFILES_DIR/Brewfile" ]]; then
            log "brew bundle install …"
            brew bundle --file="$DOTFILES_DIR/Brewfile" install
        fi
    elif is_debian; then
        bash "$DOTFILES_DIR/scripts/install/debian.sh" "$profile"
    else
        warn "Unknown OS — skipping package install. Run distro installer manually."
    fi
}

install_fonts() {
    local profile="$1"
    if [[ "$profile" == "server-headless" ]]; then
        log "skipping Nerd Font (headless profile)"
        return 0
    fi
    log "installing Nerd Font …"
    bash "$DOTFILES_DIR/scripts/install/nerd-fonts.sh" || warn "font install failed (non-fatal)"
}

apply_macos_defaults() {
    if is_macos && [[ -x "$DOTFILES_DIR/macos/defaults.sh" ]]; then
        log "applying macOS defaults …"
        bash "$DOTFILES_DIR/macos/defaults.sh" || warn "macOS defaults reported errors"
    fi
}

install_cursor_extensions() {
    local profile="$1"
    if [[ "$profile" == "server-headless" ]]; then
        return 0
    fi
    if has cursor && [[ -x "$DOTFILES_DIR/scripts/cursor/install-cursor-extensions.sh" ]]; then
        log "syncing Cursor extensions …"
        bash "$DOTFILES_DIR/scripts/cursor/install-cursor-extensions.sh" || warn "cursor extension sync had errors"
    fi
}

# -----------------------------------------------------------------------------
# Symlinks
# -----------------------------------------------------------------------------
install_symlinks() {
    log "creating symlinks …"
    bash "$DOTFILES_DIR/scripts/install/symlinks.sh"
}

# -----------------------------------------------------------------------------
# Doctor
# -----------------------------------------------------------------------------
run_doctor() {
    if [[ -x "$DOTFILES_DIR/scripts/doctor.sh" ]]; then
        bash "$DOTFILES_DIR/scripts/doctor.sh"
    else
        warn "scripts/doctor.sh not yet present"
    fi
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
main() {
    local mode="full"
    for arg in "$@"; do
        case "$arg" in
            --link-only)     mode="link";;
            --packages-only) mode="pkg";;
            --doctor)        mode="doctor";;
            --profile=*)     ;;
            -h|--help)
                grep -E '^# ' "$0" | sed 's/^# //'
                exit 0
                ;;
            *) err "unknown arg: $arg"; exit 2;;
        esac
    done

    local profile
    profile="$(detect_profile "$@")"
    log "OS: $(uname -s)  profile: $profile  host: $(hostname -s 2>/dev/null || hostname)"

    case "$mode" in
        link)   install_symlinks ;;
        pkg)    install_packages "$profile" ;;
        doctor) run_doctor ;;
        full)
            install_packages "$profile" || warn "package install reported errors"
            install_symlinks
            install_fonts "$profile"
            apply_macos_defaults
            install_cursor_extensions "$profile"
            run_doctor || true
            ok "bootstrap complete (profile: $profile)"
            ;;
    esac
}

main "$@"

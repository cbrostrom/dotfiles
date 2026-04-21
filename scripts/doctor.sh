#!/usr/bin/env bash
# =============================================================================
# scripts/doctor.sh — diagnostic for dotfiles installation
# =============================================================================
# Reports OS, profile, symlinks, missing tools, syntax errors.
# Read-only — does not modify the system.
# =============================================================================

set -uo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ -t 1 ]]; then
    G='\033[0;32m'; Y='\033[1;33m'; R='\033[0;31m'; B='\033[0;34m'; N='\033[0m'
else
    G=''; Y=''; R=''; B=''; N=''
fi
ok()   { printf "${G}✓${N} %s\n" "$*"; }
warn() { printf "${Y}⚠${N} %s\n" "$*"; }
bad()  { printf "${R}✗${N} %s\n" "$*"; }
hdr()  { printf "\n${B}━━ %s ━━${N}\n" "$*"; }

is_macos()  { [[ "$(uname -s)" == "Darwin" ]]; }
is_linux()  { [[ "$(uname -s)" == "Linux"  ]]; }
is_wsl()    { is_linux && { [[ -n "${WSL_DISTRO_NAME:-}" ]] || grep -qiE '(microsoft|wsl)' /proc/version 2>/dev/null; }; }
is_debian() { is_linux && [[ -f /etc/debian_version ]]; }

# ----- environment -----
hdr "Environment"
echo "OS:        $(uname -s) $(uname -r)"
echo "Host:      $(hostname -s 2>/dev/null || hostname)"
echo "Shell:     ${SHELL:-?}"
echo "DOTFILES:  $DOTFILES_DIR"

profile=""
[[ -f "$HOME/.local-config" ]] && profile="$(grep -E '^PROFILE=' "$HOME/.local-config" 2>/dev/null | cut -d= -f2 | tr -d '"' | tr -d "'")"
[[ -z "$profile" ]] && {
    if is_wsl; then profile="wsl"
    elif is_macos; then profile="desktop-full"
    elif [[ -z "${DISPLAY:-}" && -z "${WAYLAND_DISPLAY:-}" ]]; then profile="server-headless"
    else profile="desktop-full"
    fi
}
echo "Profile:   $profile"

# ----- symlinks -----
hdr "Symlinks"
check_link() {
    local target="$1" expect="$2"
    if [[ -L "$target" ]]; then
        local actual
        actual="$(readlink "$target")"
        if [[ "$actual" == "$expect" || "$actual" == *"$expect"* ]]; then
            ok "$target → $actual"
        else
            warn "$target → $actual (expected $expect)"
        fi
    elif [[ -e "$target" ]]; then
        warn "$target exists but is not a symlink"
    else
        bad "$target missing"
    fi
}
check_link "$HOME/.zshrc"     "$DOTFILES_DIR/.zshrc"
check_link "$HOME/.zshenv"    "$DOTFILES_DIR/.zshenv"
check_link "$HOME/.gitconfig" "$DOTFILES_DIR/.gitconfig"

# ----- syntax -----
hdr "Shell syntax"
syn_err=0
for f in "$DOTFILES_DIR"/.zshrc "$DOTFILES_DIR"/.zshenv "$DOTFILES_DIR"/zsh/*.zsh "$DOTFILES_DIR"/zsh/lib/*.sh; do
    [[ -f "$f" ]] || continue
    case "$f" in
        *.zsh|*/.zshrc|*/.zshenv) zsh -n "$f" 2>&1 && ok "$(basename "$f")" || { bad "$(basename "$f")"; syn_err=$((syn_err+1)); } ;;
        *.sh)                     bash -n "$f" 2>&1 && ok "$(basename "$f")" || { bad "$(basename "$f")"; syn_err=$((syn_err+1)); } ;;
    esac
done

# ----- expected tools -----
hdr "Tools"
need_core=(zsh git curl)
need_modern=(starship zoxide fzf bat eza rg fd zellij)
need_workflow=(atuin mise direnv carapace lazygit gh)

for cmd in "${need_core[@]}"; do
    command -v "$cmd" >/dev/null 2>&1 && ok "$cmd" || bad "$cmd missing (REQUIRED)"
done
echo
for cmd in "${need_modern[@]}"; do
    command -v "$cmd" >/dev/null 2>&1 && ok "$cmd" || warn "$cmd missing"
done
echo
for cmd in "${need_workflow[@]}"; do
    command -v "$cmd" >/dev/null 2>&1 && ok "$cmd" || warn "$cmd missing (workflow)"
done

# ----- secrets -----
hdr "Secrets"
if [[ -f "$HOME/.local-secrets" ]]; then
    perms="$(stat -f '%Lp' "$HOME/.local-secrets" 2>/dev/null || stat -c '%a' "$HOME/.local-secrets" 2>/dev/null)"
    if [[ "$perms" == "600" ]]; then
        ok "~/.local-secrets exists (chmod 600)"
    else
        warn "~/.local-secrets has perms $perms — should be 600"
    fi
else
    warn "~/.local-secrets not present (copy from .local-secrets.example)"
fi

# ----- summary -----
hdr "Summary"
if (( syn_err > 0 )); then
    bad "$syn_err shell syntax error(s)"
    exit 1
fi
ok "Doctor completed."

#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export DOTFILES_DIR

# --- gum detection ---
ensure_gum() {
    command -v gum >/dev/null 2>&1 && return 0
    echo "gum not found — required for this TUI."
    if [[ "$(uname -s)" == "Darwin" ]] && command -v brew >/dev/null 2>&1; then
        echo "Install via: brew install gum"
        read -rp "Auto-install now? [y/N] " ans
        if [[ "$ans" =~ ^[Yy]$ ]]; then
            brew install gum && return 0
        fi
    elif [[ -f /etc/debian_version ]]; then
        echo "Install via: sudo apt install gum"
        read -rp "Auto-install now? [y/N] " ans
        if [[ "$ans" =~ ^[Yy]$ ]]; then
            sudo apt install -y gum && return 0
        fi
    fi
    echo "Please install gum and re-run. Exiting."
    exit 1
}

# --- main loop ---
main() {
    ensure_gum
    source "$DOTFILES_DIR/tui/status.sh"
    source "$DOTFILES_DIR/tui/update.sh"
    source "$DOTFILES_DIR/tui/install.sh"

    # Direct mode: dotfiles --update / --install / --doctor
    case "${1:-}" in
        --update)  run_update;  return ;;
        --install) run_install; return ;;
        --doctor)  bash "$DOTFILES_DIR/scripts/doctor.sh"; return ;;
    esac

    local version git_hash
    version="$(cat "$DOTFILES_DIR/VERSION" 2>/dev/null || echo "?")"
    git_hash="$(git -C "$DOTFILES_DIR" rev-parse --short HEAD 2>/dev/null || echo "?")"

    while true; do
        ACTION=$(printf "Install / Setup\nUpdate\nTools\nStatus\nQuit" | fzf \
            --height=10 --layout=reverse --border \
            --prompt='dotfiles › ' \
            --header="v${version} (${git_hash})" \
            --no-preview) || break

        case "$ACTION" in
            "Install / Setup") run_install ;;
            "Update")          run_update ;;
            "Tools")           run_tools ;;
            "Status")          clear; show_status; read -rsp "Press any key…" -n1; echo ;;
            "Quit"|"")         break ;;
        esac
    done
}

run_tools() {
    CATEGORY=$(printf "VSCodium\nSymlinks\nFonts\nSecrets\n← Back" | fzf \
        --height=10 --layout=reverse --border \
        --prompt='tools › ' \
        --no-preview) || return

    case "$CATEGORY" in
        "VSCodium") bash "$DOTFILES_DIR/tui/tools/vscodium.sh" ;;
        "Symlinks") bash "$DOTFILES_DIR/tui/tools/symlinks.sh" ;;
        "Fonts")    bash "$DOTFILES_DIR/tui/tools/fonts.sh" ;;
        "Secrets")  bash "$DOTFILES_DIR/tui/tools/secrets.sh" ;;
        "← Back"|"") return ;;
    esac
}

main "$@"

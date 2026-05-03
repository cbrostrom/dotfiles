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

    while true; do
        clear
        show_status   # from tui/status.sh — prints status block

        ACTION=$(gum choose \
            "Install / Setup" \
            "Update" \
            "Tools" \
            "Quit" \
            --header "ACTIONS" \
            --cursor "› " \
            2>/dev/null) || break

        case "$ACTION" in
            "Install / Setup") run_install ;;
            "Update")          run_update ;;
            "Tools")           run_tools ;;
            "Quit"|"")         break ;;
        esac
    done
}

run_tools() {
    CATEGORY=$(gum choose \
        "Zed" \
        "Symlinks" \
        "Fonts" \
        "Secrets" \
        "← Back" \
        --header "TOOLS" 2>/dev/null) || return

    case "$CATEGORY" in
        "Zed")      bash "$DOTFILES_DIR/tui/tools/zed.sh" ;;
        "Symlinks") bash "$DOTFILES_DIR/tui/tools/symlinks.sh" ;;
        "Fonts")    bash "$DOTFILES_DIR/tui/tools/fonts.sh" ;;
        "Secrets")  bash "$DOTFILES_DIR/tui/tools/secrets.sh" ;;
        "← Back"|"") return ;;
    esac
}

main "$@"

#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

run_install() {
    echo
    gum style --bold --foreground 220 "INSTALL / SETUP"

    local profile="unknown"
    if [[ "$(uname -s)" == "Darwin" ]]; then
        profile="macOS / desktop-full"
    elif grep -qi microsoft /proc/version 2>/dev/null; then
        profile="WSL / wsl"
    elif [[ -f /etc/debian_version ]]; then
        profile="Linux / desktop-full"
    fi
    gum style --foreground 8 "  Detected: $profile"
    echo

    local opts=("Packages (brew / apt)" "Symlinks" "Fonts" "Zed config")
    [[ "$(uname -s)" == "Darwin" ]] && opts+=("macOS defaults")

    mapfile -t SELECTED < <(
        gum choose --no-limit \
            --header "Select components to install:" \
            --selected "Symlinks,Zed config" \
            "${opts[@]}" 2>/dev/null
    )

    [[ ${#SELECTED[@]} -eq 0 ]] && { echo "Nothing selected."; return; }

    echo
    gum style --foreground 8 "Will install:"
    for s in "${SELECTED[@]}"; do
        gum style --foreground 8 "  • $s"
    done
    echo

    gum confirm "Run selected steps?" 2>/dev/null || return

    local failed=()

    _spin_install() {
        local title="$1"; shift
        if gum spin --title "$title" -- "$@"; then
            gum style --foreground 10 "  ✓ $title"
        else
            gum style --foreground 9  "  ✗ $title"
            failed+=("$title")
        fi
    }

    for step in "${SELECTED[@]}"; do
        case "$step" in
            "Packages (brew / apt)")
                _spin_install "Installing packages" bash "$DOTFILES_DIR/bootstrap.sh" --packages-only ;;
            "Symlinks")
                _spin_install "Creating symlinks" bash "$DOTFILES_DIR/scripts/install/symlinks.sh" ;;
            "Fonts")
                _spin_install "Installing fonts" bash "$DOTFILES_DIR/scripts/install/nerd-fonts.sh" ;;
            "Zed config")
                _spin_install "Setting up Zed" bash "$DOTFILES_DIR/scripts/zed/install-zed-config.sh" ;;
            "macOS defaults")
                _spin_install "Applying macOS defaults" bash "$DOTFILES_DIR/macos/defaults.sh" ;;
        esac
    done

    echo
    if [[ ${#failed[@]} -eq 0 ]]; then
        gum style --foreground 10 --bold "Setup complete."
    else
        gum style --foreground 9 --bold "Completed with issues:"
        for f in "${failed[@]}"; do gum style --foreground 9 "  • $f"; done
    fi
    echo
    read -rsp "Press any key to return…" -n1
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_install
fi

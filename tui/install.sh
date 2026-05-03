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

    local _tmpsel
    _tmpsel="$(mktemp)"
    gum choose --no-limit \
        --header "Select components to install:" \
        --selected "Symlinks,Zed config" \
        "${opts[@]}" > "$_tmpsel" || true
    SELECTED=()
    while IFS= read -r line; do
        [[ -n "$line" ]] && SELECTED+=("$line")
    done < "$_tmpsel"
    rm -f "$_tmpsel"

    [[ ${#SELECTED[@]} -eq 0 ]] && { echo "Nothing selected."; return; }

    echo
    gum style --foreground 8 "Will install:"
    for s in "${SELECTED[@]}"; do
        gum style --foreground 8 "  • $s"
    done
    echo

    gum confirm "Run selected steps?" || return

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
                _spin_install "Installing packages" bash "$DOTFILES_DIR/bootstrap.sh" --packages-only
                gum style --foreground 8 "    brew (macOS) / apt (Linux) — se bootstrap.sh for liste" ;;
            "Symlinks")
                _spin_install "Creating symlinks" bash "$DOTFILES_DIR/scripts/install/symlinks.sh"
                gum style --foreground 8 "    ~/.zshrc, ~/.gitconfig, ~/.zshenv og øvrige dotfiler" ;;
            "Fonts")
                _spin_install "Installing fonts" bash "$DOTFILES_DIR/scripts/install/nerd-fonts.sh"
                gum style --foreground 8 "    Hack Nerd Font Mono → ~/Library/Fonts (mac) / ~/.local/share/fonts (linux)" ;;
            "Zed config")
                _spin_install "Setting up Zed" bash "$DOTFILES_DIR/scripts/zed/install-zed-config.sh"
                gum style --foreground 8 "    settings.json (base→local merge), keymap.json, rules, auto_install_extensions" ;;
            "macOS defaults")
                _spin_install "Applying macOS defaults" bash "$DOTFILES_DIR/macos/defaults.sh"
                gum style --foreground 8 "    Dock, Finder, trackpad, screenshots — se macos/defaults.sh" ;;
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

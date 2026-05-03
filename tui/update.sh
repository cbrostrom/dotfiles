#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

run_update() {
    echo
    gum style --bold --foreground 220 "UPDATE"
    echo

    local failed=()

    _spin() {
        local title="$1"; shift
        if gum spin --title "$title" -- "$@"; then
            gum style --foreground 10 "  ✓ $title"
        else
            gum style --foreground 9  "  ✗ $title"
            failed+=("$title")
        fi
    }

    _spin "Pulling latest from git" \
        git -C "$DOTFILES_DIR" pull --rebase --autostash

    _spin "Updating symlinks" \
        bash "$DOTFILES_DIR/scripts/install/symlinks.sh"

    _spin "Syncing Zed config" \
        bash "$DOTFILES_DIR/scripts/zed/install-zed-config.sh"

    echo
    gum style --foreground 8 "  Running doctor…"
    if bash "$DOTFILES_DIR/scripts/doctor.sh"; then
        gum style --foreground 10 "  ✓ Running doctor"
    else
        gum style --foreground 9  "  ✗ Running doctor"
        failed+=("Running doctor")
    fi

    echo
    if [[ ${#failed[@]} -eq 0 ]]; then
        gum style --foreground 10 --bold "All done."
    else
        gum style --foreground 9 --bold "Completed with issues:"
        for f in "${failed[@]}"; do
            gum style --foreground 9 "  • $f"
        done
    fi
    echo
    read -rsp "Press any key to return…" -n1
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_update
fi

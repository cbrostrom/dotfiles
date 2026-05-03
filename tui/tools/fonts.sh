#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

gum confirm "Install / reinstall Nerd Fonts?" 2>/dev/null || exit 0
gum spin --title "Installing Nerd Fonts…" -- \
    bash "$DOTFILES_DIR/scripts/install/nerd-fonts.sh"
gum style --foreground 10 "Done."
read -rsp "Press any key…" -n1

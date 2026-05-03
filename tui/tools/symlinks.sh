#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

ACTION=$(gum choose \
    "Re-link all" \
    "Check status" \
    "← Back" \
    --header "TOOLS › SYMLINKS") || exit 0

case "$ACTION" in
    "Re-link all")
        gum confirm "Re-create all symlinks?" || exit 0
        gum spin --title "Re-linking…" -- \
            bash "$DOTFILES_DIR/scripts/install/symlinks.sh"
        gum style --foreground 10 "Done."
        read -rsp "Press any key…" -n1
        ;;
    "Check status")
        echo
        bash "$DOTFILES_DIR/scripts/doctor.sh" 2>/dev/null | less -R
        ;;
    "← Back"|"") exit 0 ;;
esac

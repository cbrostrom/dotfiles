#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

ACTION=$(gum choose \
    "Merge settings (base → local)" \
    "Diff base vs local" \
    "Promote change to base" \
    "← Back" \
    --header "TOOLS › ZED") || exit 0

case "$ACTION" in
    "Merge settings (base → local)")
        gum spin --title "Merging Zed settings…" -- \
            bash "$DOTFILES_DIR/scripts/zed/zed-update-local.sh"
        gum style --foreground 10 "Done."
        read -rsp "Press any key…" -n1
        ;;
    "Diff base vs local")
        echo
        bash "$DOTFILES_DIR/scripts/zed/zed-diff-base.sh" | less -R
        ;;
    "Promote change to base")
        echo
        gum style --foreground 11 "Steps to promote a local change to base:"
        gum style --foreground 8  "  1. Review diff below"
        gum style --foreground 8  "  2. Edit .config/zed/settings.base.json"
        gum style --foreground 8  "  3. git commit + push"
        gum style --foreground 8  "  4. Other machines pick up on next update"
        echo
        bash "$DOTFILES_DIR/scripts/zed/zed-diff-base.sh" | less -R
        ;;
    "← Back"|"") exit 0 ;;
esac

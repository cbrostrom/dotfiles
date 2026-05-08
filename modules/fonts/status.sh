#!/usr/bin/env bash
# Healthy if a JetBrainsMono Nerd Font file is present in the OS font dir.
. "$DOTFILES_DIR/modules/_lib/platform.sh" 2>/dev/null || {
    DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
    . "$DOTFILES_DIR/modules/_lib/platform.sh"
}

if is_macos; then
    dir="$HOME/Library/Fonts"
else
    dir="$HOME/.local/share/fonts"
fi
[[ -d "$dir" ]] || exit 1
ls "$dir" 2>/dev/null | grep -qiE "(jetbrains|hack).*nerd" || exit 1
exit 0

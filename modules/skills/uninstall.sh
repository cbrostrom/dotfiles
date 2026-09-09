#!/usr/bin/env bash
set -euo pipefail
. "$DOTFILES_DIR/modules/_lib/log.sh"

# Unlink discovery symlinks only — never delete ~/dotfiles/.agents/skills.
for link in "$HOME/.cursor/skills" "$HOME/.agents/skills"; do
    if [[ -L "$link" ]]; then
        rm -f "$link"
        ok "removed $link"
    elif [[ -e "$link" ]]; then
        warn "$link exists and is not a symlink — leaving it untouched"
    fi
done

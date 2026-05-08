#!/usr/bin/env bash
# Healthy iff the canonical user-facing symlinks exist and point into the dotfiles dir.
DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
required=(
    "$HOME/.zshrc"
    "$HOME/.zshenv"
    "$HOME/.gitconfig"
    "$HOME/.gitignore_global"
)
for link in "${required[@]}"; do
    [[ -L "$link" ]] || exit 1
    target="$(readlink -f "$link" 2>/dev/null || echo "")"
    [[ "$target" == "$DOTFILES_DIR"* ]] || exit 1
done
exit 0

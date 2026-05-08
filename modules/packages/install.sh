#!/usr/bin/env bash
set -euo pipefail
. "$DOTFILES_DIR/modules/_lib/log.sh"
. "$DOTFILES_DIR/modules/_lib/platform.sh"

profile="$(profile_tag)"

if is_macos; then
    if ! has brew; then
        warn "Homebrew not installed. Install from https://brew.sh, then re-run."
        exit 1
    fi
    if [[ -f "$DOTFILES_DIR/Brewfile" ]]; then
        log "brew bundle install …"
        brew bundle --file="$DOTFILES_DIR/Brewfile" install
        ok "brew bundle complete"
    else
        warn "Brewfile not found at $DOTFILES_DIR/Brewfile"
    fi
elif is_debian; then
    bash "$DOTFILES_DIR/scripts/install/debian.sh" "$profile"
else
    warn "unknown OS $(uname -s) — skipping package install (run distro installer manually)"
fi

#!/usr/bin/env bash
set -euo pipefail
. "$DOTFILES_DIR/modules/_lib/log.sh"
. "$DOTFILES_DIR/modules/_lib/platform.sh"

profile="$(profile_tag)"

# Merge base Brewfile + host overlay into a tempfile, echo its path.
# Overlay precedence: Brewfile (base) + Brewfile.host-<slug> (host-specific).
# Profile overlays (Brewfile.<profile>) are also picked up if present.
brewfile_merged() {
    local base="$DOTFILES_DIR/Brewfile"
    [[ -f "$base" ]] || return 1
    local host profile_t merged
    host="$(host_slug)"
    profile_t="$(profile_tag)"
    merged="$(mktemp -t Brewfile.merged.XXXXXX)"
    {
        cat "$base"
        for overlay in \
            "$DOTFILES_DIR/Brewfile.$profile_t" \
            "$DOTFILES_DIR/Brewfile.host-$host"; do
            if [[ -f "$overlay" ]]; then
                printf '\n# --- overlay: %s ---\n' "$(basename "$overlay")"
                cat "$overlay"
            fi
        done
    } > "$merged"
    echo "$merged"
}

if is_macos; then
    if ! has brew; then
        warn "Homebrew not installed. Install from https://brew.sh, then re-run."
        exit 1
    fi
    if merged="$(brewfile_merged)"; then
        log "brew bundle install (merged: base + host-$(host_slug) overlay) …"
        brew bundle --file="$merged" install
        rm -f "$merged"
        ok "brew bundle complete"
    else
        warn "Brewfile not found at $DOTFILES_DIR/Brewfile"
    fi
elif is_debian; then
    bash "$DOTFILES_DIR/scripts/install/debian.sh" "$profile"
else
    warn "unknown OS $(uname -s) — skipping package install (run distro installer manually)"
fi

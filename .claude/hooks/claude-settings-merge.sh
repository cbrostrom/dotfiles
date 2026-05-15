#!/usr/bin/env bash
# claude-settings-merge.sh — SessionStart hook. Regenerates settings.local.json
# if any tracked input is newer than the last attestation. Never blocks session.
set -eu

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/dotfiles}"
[ -d "$DOTFILES_DIR" ] || DOTFILES_DIR="$HOME/.config/dotfiles"
CLAUDE_DIR="$DOTFILES_DIR/.claude"
MOD_DIR="$DOTFILES_DIR/modules/claude-settings"
MERGE="$MOD_DIR/merge.sh"
ATTEST="$CLAUDE_DIR/.settings-attestation"

# shellcheck source=/dev/null
[ -f "$MOD_DIR/lib/platform.sh" ] && source "$MOD_DIR/lib/platform.sh"

# Cross-platform stat
_mtime() { stat -f %m "$1" 2>/dev/null || stat -c %Y "$1" 2>/dev/null || echo 0; }

# Newest input mtime across base + all platform fragments + override (if present) + rules
newest_input=$(
    for f in "$CLAUDE_DIR"/settings.base.json \
             "$CLAUDE_DIR"/settings.*.json \
             "$CLAUDE_DIR"/_merge-config.json; do
        [ -e "$f" ] && _mtime "$f"
    done | sort -n | tail -1
)

last_merge=$(_mtime "$ATTEST")

# Up-to-date — no-op
[ "${newest_input:-0}" -le "${last_merge:-0}" ] && exit 0

# Run merge; never block session
"$MERGE" 2>&1 || {
    echo "[claude-settings] merge failed — keeping previous settings.local.json"
    exit 0
}
echo "[claude-settings] regenerated settings.local.json"

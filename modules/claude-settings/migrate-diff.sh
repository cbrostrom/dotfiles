#!/usr/bin/env bash
# migrate-diff.sh — for each snapshot in .attic/settings-pre-merge/<host>.json,
# compute what merge.sh WOULD produce for that host's platform, then jq-diff.
# Output goes to stdout; one report per host.
set -euo pipefail

MOD_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="${DOTFILES_DIR:-$HOME/dotfiles}"
ATTIC="$DOTFILES_DIR/.attic/settings-pre-merge"
[ -d "$ATTIC" ] || { echo "no snapshots — run snapshot-hosts.sh first" >&2; exit 1; }

# host → platform map. Edit if host list changes.
host_platform() {
    case "$1" in
        GY-M-WHKK2PF6N7|akqamacbook) echo darwin ;;
        superbro|linuxbro)           echo linux ;;
        monsterbro-wsl)              echo wsl ;;
        *)                           echo linux ;;
    esac
}

for snap in "$ATTIC"/*.json; do
    host=$(basename "$snap" .json)
    platform=$(host_platform "$host")
    echo "════ $host (platform=$platform) ════"
    computed=$(mktemp)
    CLAUDE_DIR="$DOTFILES_DIR/.claude" PLATFORM="$platform" "$MOD_DIR/merge.sh" >/dev/null
    cp "$DOTFILES_DIR/.claude/settings.local.json" "$computed"

    echo "--- keys present in old snapshot but missing from computed ---"
    jq -nS --slurpfile a "$snap" --slurpfile b "$computed" \
        '[$a[0] | paths(scalars)] - [$b[0] | paths(scalars)]' \
       2>/dev/null | head -40 || true

    echo "--- keys in computed not in snapshot ---"
    jq -nS --slurpfile a "$snap" --slurpfile b "$computed" \
        '[$b[0] | paths(scalars)] - [$a[0] | paths(scalars)]' \
       2>/dev/null | head -40 || true

    echo "--- value differences for shared keys (first 40 lines) ---"
    diff <(jq -S . "$snap") <(jq -S . "$computed") | head -40 || true
    rm -f "$computed"
done

# Restore: regenerate against the actual local platform so settings.local.json
# is correct for whatever host runs this script.
"$MOD_DIR/merge.sh" >/dev/null

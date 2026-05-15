#!/usr/bin/env bash
# snapshot-hosts.sh — copy each host's current settings.local.json to
# .attic/settings-pre-merge/<host>.json for migration diffing.
set -euo pipefail

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/dotfiles}"
ATTIC="$DOTFILES_DIR/.attic/settings-pre-merge"
mkdir -p "$ATTIC"

# Local host snapshot
hostname_short=$(hostname -s)
if [ -f "$DOTFILES_DIR/.claude/settings.local.json" ]; then
    cp "$DOTFILES_DIR/.claude/settings.local.json" "$ATTIC/${hostname_short}.json"
    echo "[snapshot] $hostname_short → $ATTIC/${hostname_short}.json"
else
    echo "[snapshot] $hostname_short SKIPPED (no settings.local.json)"
fi

# Remote hosts via SSH
for spec in "superbro::superbro" \
            "christian@100.100.1.100::linuxbro"; do
    target="${spec%%::*}"
    label="${spec##*::}"
    if ssh -o ConnectTimeout=5 -o BatchMode=yes "$target" 'test -f ~/dotfiles/.claude/settings.local.json' 2>/dev/null; then
        ssh "$target" 'cat ~/dotfiles/.claude/settings.local.json' > "$ATTIC/${label}.json"
        echo "[snapshot] $label → $ATTIC/${label}.json"
    else
        echo "[snapshot] $label SKIPPED (unreachable or no settings.local.json)"
    fi
done

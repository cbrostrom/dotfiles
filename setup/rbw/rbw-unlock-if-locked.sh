#!/usr/bin/env bash
# rbw-unlock-if-locked.sh — LaunchAgent helper; prompt only when vault is locked.
set -euo pipefail

export PATH="/opt/homebrew/bin:/usr/local/bin:${PATH:-}"

command -v rbw >/dev/null 2>&1 || exit 0

if rbw unlocked >/dev/null 2>&1; then
    exit 0
fi

exec rbw unlock

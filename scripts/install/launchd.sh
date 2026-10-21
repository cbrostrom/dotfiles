#!/usr/bin/env bash
# Install launchd agents (macOS): paseo-watchdog and memory-curator.
# Idempotent: renders plists with the repo path, reloads only when content changed.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
AGENTS_DIR="$HOME/Library/LaunchAgents"
DOMAIN="gui/$(id -u)"

[[ "$(uname -s)" == "Darwin" ]] || exit 0
mkdir -p "$AGENTS_DIR"

install_plist() {
    local src="$1" name dest tmp
    name="$(basename "$src")"
    dest="$AGENTS_DIR/$name"
    tmp="$(mktemp)"
    sed "s|/Users/Christian.Brostrom/dotfiles|$ROOT|g" "$src" >"$tmp"
    if [[ -f "$dest" ]] && cmp -s "$tmp" "$dest"; then
        rm -f "$tmp"
        printf 'launchd: %s up to date\n' "$name"
        return 0
    fi
    mv "$tmp" "$dest"
    launchctl bootout "$DOMAIN" "$dest" 2>/dev/null || true
    launchctl bootstrap "$DOMAIN" "$dest" || printf 'warn: could not load %s\n' "$name" >&2
    printf 'launchd: installed %s\n' "$name"
}

install_plist "$ROOT/scripts/paseo/com.christian.paseo-watchdog.plist"
install_plist "$ROOT/scripts/vault/com.christian.memory-curator.plist"

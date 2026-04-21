#!/usr/bin/env bash
# =============================================================================
# scripts/install/debian.sh — apt provisioning for all Debian environments
# Covers: linuxbro (homelab), superbro (VPS), monsterbro WSL
# =============================================================================
# Usage: ./debian.sh <profile>
#   <profile>: desktop-full | server-headless | wsl
# =============================================================================

set -euo pipefail

PROFILE="${1:-server-headless}"
LIST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/apt"

log() { printf "[debian] %s\n" "$*"; }

if ! command -v apt-get >/dev/null 2>&1; then
    echo "apt-get not found — not a Debian/Ubuntu system." >&2
    exit 1
fi

read_list() {
    local f="$1"
    [[ -f "$f" ]] || return 0
    grep -vE '^\s*(#|$)' "$f" | tr '\n' ' '
}

PKGS=""
PKGS+=" $(read_list "$LIST_DIR/base.txt")"

case "$PROFILE" in
    desktop-full)    PKGS+=" $(read_list "$LIST_DIR/desktop.txt")" ;;
    server-headless) PKGS+=" $(read_list "$LIST_DIR/server.txt")" ;;
    wsl)             PKGS+=" $(read_list "$LIST_DIR/wsl.txt")" ;;
    *) echo "Unknown profile: $PROFILE" >&2; exit 2;;
esac

log "profile=$PROFILE"
log "running apt update + install (sudo)…"

sudo apt-get update -y
# shellcheck disable=SC2086
sudo apt-get install -y --no-install-recommends $PKGS

log "done."

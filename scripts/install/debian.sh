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

# gum (Charmbracelet) — not in standard apt repos
if ! command -v gum >/dev/null 2>&1; then
    log "adding Charmbracelet apt repo for gum…"
    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://repo.charm.sh/apt/gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/charm.gpg
    echo "deb [signed-by=/etc/apt/keyrings/charm.gpg] https://repo.charm.sh/apt/ * *" \
        | sudo tee /etc/apt/sources.list.d/charm.list >/dev/null
    sudo apt-get update -y && sudo apt-get install -y gum
fi

# gh (GitHub CLI) — not in standard apt repos
if ! command -v gh >/dev/null 2>&1; then
    log "adding GitHub CLI apt repo for gh…"
    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
        | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
    sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
        | sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null
    sudo apt-get update -y && sudo apt-get install -y gh
fi

log "done."

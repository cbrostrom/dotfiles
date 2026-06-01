#!/usr/bin/env bash
# Stop hook: export engram vault as sync chunks and push to git.
#
# SYNC_REPO (git repo with chunks) is separate from VAULT_DIR (local engram.db).
# Path override: echo /path/to/repo > ~/.engram/sync-repo
# Default: ~/engram-sync on all platforms
set -uo pipefail

# --- Binary ---
ENGRAM_BIN="${HOME}/go/bin/engram"
if [[ ! -x "${ENGRAM_BIN}" ]] && { [[ -n "${WSL_DISTRO_NAME:-}" ]] || grep -qi microsoft /proc/version 2>/dev/null; }; then
    ENGRAM_BIN="/mnt/c/Users/${USER}/go/bin/engram.exe"
fi

# --- Paths ---
if [[ -f "${HOME}/.engram/sync-repo" ]]; then
    SYNC_REPO="$(cat "${HOME}/.engram/sync-repo")"
else
    SYNC_REPO="${HOME}/engram-sync"
fi
VAULT_DIR="${HOME}/.engram/personal"

# --- Guards ---
[[ -d "${SYNC_REPO}/.git" ]] || exit 0
[[ -x "${ENGRAM_BIN}" ]]     || exit 0
[[ -d "${VAULT_DIR}" ]]      || exit 0

# --- Export chunks from vault (5s max) ---
timeout 5 ENGRAM_DATA_DIR="${VAULT_DIR}" "${ENGRAM_BIN}" sync 2>/dev/null || exit 0

# --- Copy chunks into sync repo ---
if [[ -d "${VAULT_DIR}/.engram" ]]; then
    mkdir -p "${SYNC_REPO}/personal/.engram"
    rsync -a --quiet "${VAULT_DIR}/.engram/" "${SYNC_REPO}/personal/.engram/" 2>/dev/null || true
fi

# --- Commit and push if changed (15s max) ---
if [[ -n "$(git -C "${SYNC_REPO}" status --porcelain 2>/dev/null)" ]]; then
    git -C "${SYNC_REPO}" add .
    timeout 5 git -C "${SYNC_REPO}" commit -m "sync: $(date '+%Y-%m-%d %H:%M')" --quiet
    timeout 10 git -C "${SYNC_REPO}" push --quiet 2>/dev/null || true
fi

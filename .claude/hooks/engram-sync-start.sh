#!/usr/bin/env bash
# SessionStart hook: pull latest engram sync chunks from git and import into vault.
#
# SYNC_REPO (git repo with chunks) is separate from VAULT_DIR (local engram.db).
# Path override: echo /path/to/repo > ~/.engram/sync-repo
# Default: ~/engram-sync on all platforms (clone git@github.com:cbrostrom/engram.git there)
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

# --- Pull (10s max) ---
timeout 10 git -C "${SYNC_REPO}" pull --quiet --ff-only 2>/dev/null || true

# --- Sync chunks into vault dir then import (5s max) ---
if [[ -d "${SYNC_REPO}/personal/.engram" ]]; then
    mkdir -p "${VAULT_DIR}/.engram"
    rsync -a --quiet "${SYNC_REPO}/personal/.engram/" "${VAULT_DIR}/.engram/" 2>/dev/null || true
fi
timeout 5 ENGRAM_DATA_DIR="${VAULT_DIR}" "${ENGRAM_BIN}" sync --import 2>/dev/null || true

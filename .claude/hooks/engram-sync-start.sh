#!/usr/bin/env bash
# SessionStart hook: pull latest engram sync chunks from git and import into vault.
# Vault:     ~/.engram/personal   (live SQLite — not git-tracked)
# Sync repo: ~/engram-sync        (exported text chunks — git-tracked)
# Silent no-op if sync repo not yet cloned or engram binary missing.
set -uo pipefail

SYNC_REPO="${HOME}/engram-sync"
[[ -d "${SYNC_REPO}/.git" ]] || exit 0
command -v engram >/dev/null 2>&1 || exit 0

git -C "${SYNC_REPO}" pull --quiet --ff-only 2>/dev/null || true
ENGRAM_DATA_DIR="${HOME}/.engram/personal" ENGRAM_SYNC_REPO="${SYNC_REPO}" \
    engram sync --import 2>/dev/null || true

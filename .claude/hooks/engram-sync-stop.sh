#!/usr/bin/env bash
# Stop hook: export engram vault as sync chunks and push to git.
# Vault:     ~/.engram/personal   (live SQLite — not git-tracked)
# Sync repo: ~/engram-sync        (exported text chunks — git-tracked)
# Silent no-op if sync repo not yet cloned or engram binary missing.
set -uo pipefail

SYNC_REPO="${HOME}/engram-sync"
[[ -d "${SYNC_REPO}/.git" ]] || exit 0
command -v engram >/dev/null 2>&1 || exit 0

ENGRAM_DATA_DIR="${HOME}/.engram/personal" ENGRAM_SYNC_REPO="${SYNC_REPO}" \
    engram sync 2>/dev/null || exit 0

if [[ -n "$(git -C "${SYNC_REPO}" status --porcelain 2>/dev/null)" ]]; then
    git -C "${SYNC_REPO}" add .
    git -C "${SYNC_REPO}" commit -m "sync: $(date '+%Y-%m-%d %H:%M')" --quiet
    git -C "${SYNC_REPO}" push --quiet 2>/dev/null || true
fi

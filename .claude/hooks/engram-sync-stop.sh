#!/usr/bin/env bash
# Stop hook: export new engram observations as sync chunks and push to git.
# Silent no-op if git repo not yet initialised in ~/.engram.
set -uo pipefail

ENGRAM_DIR="${HOME}/.engram"
[[ -d "${ENGRAM_DIR}/.git" ]] || exit 0

ENGRAM_DATA_DIR="${ENGRAM_DIR}/personal" engram sync 2>/dev/null || exit 0

cd "${ENGRAM_DIR}"
if [[ -n "$(git status --porcelain 2>/dev/null)" ]]; then
    git add .
    git commit -m "sync: $(date '+%Y-%m-%d %H:%M')" --quiet
    git push --quiet 2>/dev/null || true
fi

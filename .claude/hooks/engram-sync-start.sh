#!/usr/bin/env bash
# SessionStart hook: pull latest engram sync chunks from git and import.
# Silent no-op if git repo not yet initialised in ~/.engram.
set -uo pipefail

ENGRAM_DIR="${HOME}/.engram"
[[ -d "${ENGRAM_DIR}/.git" ]] || exit 0

git -C "${ENGRAM_DIR}" pull --quiet --ff-only 2>/dev/null || true
ENGRAM_DATA_DIR="${ENGRAM_DIR}/personal" engram sync --import 2>/dev/null || true

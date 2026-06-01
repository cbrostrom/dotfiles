#!/usr/bin/env bash
# SessionStart hook: pull latest engram sync chunks from git and import into vault.
#
# Architecture:
#   Vault dir = git repo (engram.db gitignored; chunk files tracked).
#   WSL:   vault at %USERPROFILE%\.engram, binary at %USERPROFILE%\go\bin\engram.exe
#   macOS/Linux: vault at ~/.engram, binary at ~/go/bin/engram
#
# Silent no-op if vault not yet git-initialised or binary missing.
set -uo pipefail

if [[ -n "${WSL_DISTRO_NAME:-}" ]] || grep -qi microsoft /proc/version 2>/dev/null; then
    WIN_HOME="/mnt/c/Users/${USER}"
    ENGRAM_BIN="${WIN_HOME}/go/bin/engram.exe"
    SYNC_REPO="${WIN_HOME}/.engram"
    VAULT_DIR="${SYNC_REPO}/personal"
    export WSLENV="ENGRAM_DATA_DIR/p${WSLENV:+:${WSLENV}}"
else
    ENGRAM_BIN="${HOME}/go/bin/engram"
    SYNC_REPO="${HOME}/.engram"
    VAULT_DIR="${SYNC_REPO}/personal"
fi

[[ -d "${SYNC_REPO}/.git" ]] || exit 0
[[ -x "${ENGRAM_BIN}" ]]     || exit 0

git -C "${SYNC_REPO}" pull --quiet --ff-only 2>/dev/null || true
pushd "${VAULT_DIR}" >/dev/null
ENGRAM_DATA_DIR="${VAULT_DIR}" "${ENGRAM_BIN}" sync --import 2>/dev/null || true
popd >/dev/null

#!/usr/bin/env bash
# Stop hook: export engram vault as sync chunks and push to git.
#
# Architecture:
#   Vault dir = git repo (engram.db gitignored; chunk files tracked).
#   WSL:   vault at %USERPROFILE%\.engram, binary at %USERPROFILE%\go\bin\engram.exe
#   macOS/Linux: vault at ~/.engram, binary at ~/go/bin/engram
#
# Silent no-op if vault not yet git-initialised or binary missing.
set -uo pipefail

if [[ -n "${WSL_DISTRO_NAME:-}" ]] || grep -qi microsoft /proc/version 2>/dev/null; then
    WIN_HOME="$(wslpath "$(cmd.exe /c 'echo %USERPROFILE%' 2>/dev/null | tr -d '\r\n')")"
    ENGRAM_BIN="${WIN_HOME}/go/bin/engram.exe"
    SYNC_REPO="${WIN_HOME}/.engram"
    VAULT_DIR="${SYNC_REPO}/personal"
else
    ENGRAM_BIN="${HOME}/go/bin/engram"
    SYNC_REPO="${HOME}/.engram"
    VAULT_DIR="${SYNC_REPO}/personal"
fi

[[ -d "${SYNC_REPO}/.git" ]] || exit 0
[[ -x "${ENGRAM_BIN}" ]]     || exit 0

ENGRAM_DATA_DIR="${VAULT_DIR}" "${ENGRAM_BIN}" sync 2>/dev/null || exit 0

if [[ -n "$(git -C "${SYNC_REPO}" status --porcelain 2>/dev/null)" ]]; then
    git -C "${SYNC_REPO}" add .
    git -C "${SYNC_REPO}" commit -m "sync: $(date '+%Y-%m-%d %H:%M')" --quiet
    git -C "${SYNC_REPO}" push --quiet 2>/dev/null || true
fi

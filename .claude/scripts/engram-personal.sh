#!/usr/bin/env bash
# Cross-platform engram MCP launcher for Claude Code.
#
# Platform    Binary                              Vault
# ─────────────────────────────────────────────────────────────────────
# WSL         %USERPROFILE%\go\bin\engram.exe     %USERPROFILE%\.engram
# macOS       ~/go/bin/engram                     ~/.engram
# Linux       ~/go/bin/engram                     ~/.engram
#
# Install binary:
#   Windows/WSL : (from PowerShell) go install github.com/Gentleman-Programming/engram/cmd/engram@latest
#   macOS/Linux : go install github.com/Gentleman-Programming/engram/cmd/engram@latest

set -euo pipefail

if [[ -n "${WSL_DISTRO_NAME:-}" ]] || grep -qi microsoft /proc/version 2>/dev/null; then
    WIN_HOME="$(wslpath "$(cmd.exe /c 'echo %USERPROFILE%' 2>/dev/null | tr -d '\r\n')")"
    ENGRAM_BIN="${WIN_HOME}/go/bin/engram.exe"
    # WSLENV with /p flag translates the Linux path to Windows format for engram.exe
    export ENGRAM_DATA_DIR="${WIN_HOME}/.engram/personal"
    export WSLENV="ENGRAM_DATA_DIR/p${WSLENV:+:${WSLENV}}"
else
    ENGRAM_BIN="${HOME}/go/bin/engram"
    export ENGRAM_DATA_DIR="${HOME}/.engram/personal"
fi

if [[ ! -x "${ENGRAM_BIN}" ]]; then
    echo "engram binary not found: ${ENGRAM_BIN}" >&2
    echo "Install: go install github.com/Gentleman-Programming/engram/cmd/engram@latest" >&2
    exit 1
fi

exec "${ENGRAM_BIN}" mcp

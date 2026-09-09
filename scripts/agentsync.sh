#!/usr/bin/env bash
# agentsync — keep project-level AI rules in sync (AGENTS.md ↔ Cursor rules).
# Wraps npx agentsync (PanisHandsome/ai-rules-sync, zero deps).
#
# Usage:
#   agentsync init              — scaffold AGENTS.md from codebase scan
#   agentsync sync              — sync AGENTS.md → .cursorrules (and other adapters)
#   agentsync convert <from> <to> <file>
#
# Project repos only — shared agent policy lives in AGENTS.md / .agents/.

set -euo pipefail

if ! command -v npx >/dev/null 2>&1; then
    echo "npx not found — install Node.js first" >&2
    exit 1
fi

exec npx agentsync "$@"

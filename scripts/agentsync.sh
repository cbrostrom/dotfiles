#!/usr/bin/env bash
# agentsync — keep project-level AI rules in sync across Claude Code + Cursor.
# Wraps npx agentsync (PanisHandsome/ai-rules-sync, zero deps).
#
# Usage:
#   agentsync init              — scaffold AGENTS.md from codebase scan
#   agentsync sync              — sync AGENTS.md → CLAUDE.md + .cursorrules
#   agentsync convert <from> <to> <file>
#
# Intended for project repos only — NOT for ~/.claude/CLAUDE.md (Claude-specific content).

set -euo pipefail

if ! command -v npx >/dev/null 2>&1; then
    echo "npx not found — install Node.js first" >&2
    exit 1
fi

exec npx agentsync "$@"

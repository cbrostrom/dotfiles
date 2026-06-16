#!/usr/bin/env bash
# brain-load.sh — Cursor sessionStart hook
# Runs the shared brain-load script and injects output as additional_context.
set -uo pipefail

BRAIN_LOAD="$HOME/dotfiles/.claude/hooks/brain-load.sh"

[[ -x "$BRAIN_LOAD" ]] || exit 0

output="$("$BRAIN_LOAD" 2>/dev/null)" || exit 0
[[ -z "$output" ]] && exit 0

python3 -c "import json,sys; print(json.dumps({'additional_context': sys.argv[1]}))" "$output"

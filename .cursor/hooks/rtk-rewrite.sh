#!/usr/bin/env bash
# RTK auto-rewrite hook for Cursor preToolUse:Shell.
# Cursor-specific adapter around the shared RTK command rewrite policy.
set -euo pipefail

if ! command -v rtk &>/dev/null || ! command -v jq &>/dev/null; then
  exit 0
fi

REWRITER="${DOTFILES:-$HOME/dotfiles}/scripts/rtk/rewrite-command.sh"
[[ -x "$REWRITER" ]] || exit 0

INPUT=$(cat)

# Cursor hook payloads include the tool input; keep fallbacks so the hook fails
# open if the event shape changes or a non-shell tool reaches this script.
CMD=$(echo "$INPUT" | jq -r '.tool_input.command // .input.command // .command // empty')
[[ -n "$CMD" ]] || exit 0

REWRITTEN="$("$REWRITER" "$CMD")"
[[ -n "$REWRITTEN" ]] || exit 0

UPDATED_INPUT=$(echo "$INPUT" | jq -c --arg cmd "$REWRITTEN" '
  if .tool_input and (.tool_input | type == "object") then
    .tool_input | .command = $cmd
  elif .input and (.input | type == "object") then
    .input | .command = $cmd
  else
    {command: $cmd}
  end
')

jq -n \
  --argjson updated "$UPDATED_INPUT" \
  '{
    "permission": "allow",
    "agent_message": "RTK auto-rewrite",
    "updated_input": $updated
  }'

#!/usr/bin/env bash
# RTK auto-rewrite hook for Claude Code PreToolUse:Bash.
# Claude-specific adapter around the shared RTK command rewrite policy.
set -euo pipefail

if ! command -v rtk &>/dev/null || ! command -v jq &>/dev/null; then
  exit 0
fi

REWRITER="${DOTFILES:-$HOME/dotfiles}/scripts/rtk/rewrite-command.sh"
[[ -x "$REWRITER" ]] || exit 0

INPUT=$(cat)
CMD=$(echo "$INPUT" | jq -r '.tool_input.command // empty')
[[ -n "$CMD" ]] || exit 0

REWRITTEN="$("$REWRITER" "$CMD")"
[[ -n "$REWRITTEN" ]] || exit 0

UPDATED_INPUT=$(echo "$INPUT" | jq -c --arg cmd "$REWRITTEN" '.tool_input | .command = $cmd')

jq -n \
  --argjson updated "$UPDATED_INPUT" \
  '{
    "hookSpecificOutput": {
      "hookEventName": "PreToolUse",
      "permissionDecision": "allow",
      "permissionDecisionReason": "RTK auto-rewrite",
      "updatedInput": $updated
    }
  }'

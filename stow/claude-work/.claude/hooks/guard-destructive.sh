#!/usr/bin/env bash
# PreToolUse(Bash): block catastrophic rm. Port of the pi guard-destructive hook.
cmd=$(jq -r '.tool_input.command // empty' 2>/dev/null)
[[ -z "$cmd" ]] && exit 0
if printf '%s' "$cmd" | grep -qE 'rm -rf (/[^/]|~|/home|/Users)'; then
  echo "[cc-guard] Blocked catastrophic rm." >&2
  exit 2
fi
exit 0

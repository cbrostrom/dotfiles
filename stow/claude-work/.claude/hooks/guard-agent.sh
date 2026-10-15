#!/usr/bin/env bash
# PreToolUse(Agent): deny forks (they would run on the main model) and cap spawns per session.
# Max per session: CC_MAX_AGENTS (default 6).
payload=$(cat)
sid=$(printf '%s' "$payload" | jq -r '.session_id // "nosession"')
type=$(printf '%s' "$payload" | jq -r '.tool_input.subagent_type // empty')
deny() {
  jq -cn --arg r "$1" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}'
  exit 0
}
[[ "$type" == "fork" ]] && deny "Forked subagents run on the main model; use a named subagent (runs on the forced small model)."
f="${TMPDIR:-/tmp}/cc-agent-count-$sid"
n=$(cat "$f" 2>/dev/null || echo 0)
max="${CC_MAX_AGENTS:-6}"
(( n >= max )) && deny "Subagent cap of $max reached for this session."
echo $((n + 1)) >"$f"
exit 0

#!/usr/bin/env bash
# PreToolUse(Agent): deny forks; team and repo agents keep their model, one in flight.
# Everything else is pinned to haiku and capped (CC_MAX_AGENTS, default 6 per session).
# `guard-agent.sh release` (PostToolUse) clears the in-flight marker.
payload=$(cat)
sid=$(printf '%s' "$payload" | jq -r '.session_id // "nosession"')
tmp="${TMPDIR:-/tmp}"
busy="$tmp/cc-agent-busy-$sid"
if [[ "${1:-}" == "release" ]]; then rm -f "$busy"; exit 0; fi

type=$(printf '%s' "$payload" | jq -r '.tool_input.subagent_type // empty')
bg=$(printf '%s' "$payload" | jq -r '.tool_input.run_in_background // false')
cwd=$(printf '%s' "$payload" | jq -r '.cwd // empty')
deny() {
  jq -cn --arg r "$1" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}'
  exit 0
}
[[ "$type" == "fork" ]] && deny "Forked subagents run on the main model; use a named subagent."

team=0
case "$type" in planner|coder|coder-plus|grunt) team=1 ;; esac
if (( ! team )) && [[ -n "$type" && -n "$cwd" ]]; then
  root=$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null)
  [[ -n "$root" && -f "$root/.claude/agents/$type.md" ]] && team=1
fi

if (( team )); then
  [[ "$bg" == "true" ]] && deny "Background team agents are not allowed; run them in the foreground."
  [[ -f "$busy" ]] && deny "One task in flight: wait for the running team agent to finish."
  : >"$busy"
  # Strip any call-time model so the agent's own frontmatter model applies.
  jq -cn --argjson i "$(printf '%s' "$payload" | jq -c '.tool_input | del(.model)')" \
    '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"allow",updatedInput:$i}}'
  exit 0
fi

f="$tmp/cc-agent-count-$sid"
n=$(cat "$f" 2>/dev/null || echo 0)
max="${CC_MAX_AGENTS:-6}"
(( n >= max )) && deny "Subagent cap of $max reached for this session."
echo $((n + 1)) >"$f"
jq -cn --argjson i "$(printf '%s' "$payload" | jq -c '.tool_input | .model="haiku"')" \
  '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"allow",updatedInput:$i}}'
exit 0

#!/usr/bin/env bash
# PreToolUse(Agent): deny forks; team (incl. ce-* reviewers) and repo agents keep their model,
# foreground or background, at most CC_MAX_TEAM_AGENTS (default 2) running at once.
# Everything else is pinned to haiku and capped (CC_MAX_AGENTS, default 6 per session).
# `guard-agent.sh release` (SubagentStop) frees the oldest slot of that agent type; slots
# older than 120 minutes count as crashed and are dropped.
payload=$(cat)
sid=$(printf '%s' "$payload" | jq -r '.session_id // "nosession"')
tmp="${TMPDIR:-/tmp}/agent-hooks"
mkdir -p "$tmp"
slots="$tmp/cc-team-$sid"
mkdir -p "$slots"
find "$slots" -type f -mmin +120 -delete 2>/dev/null
if [[ "${1:-}" == "release" ]]; then
  atype=$(printf '%s' "$payload" | jq -r '.agent_type // empty')
  oldest=$(ls -tr "$slots" 2>/dev/null | grep -m1 -- "^${atype:-.}" || ls -tr "$slots" 2>/dev/null | head -1)
  [[ -n "$oldest" ]] && rm -f "$slots/$oldest"
  exit 0
fi

type=$(printf '%s' "$payload" | jq -r '.tool_input.subagent_type // empty')
cwd=$(printf '%s' "$payload" | jq -r '.cwd // empty')
deny() {
  jq -cn --arg r "$1" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}'
  exit 0
}
[[ "$type" == "fork" ]] && deny "Forked subagents run on the main model; use a named subagent."

team=0
case "$type" in planner|coder|coder-lite|coder-plus|grunt|reviewer|ce-*|shopify-expert) team=1 ;; esac
if (( ! team )) && [[ -n "$type" && -n "$cwd" ]]; then
  root=$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null)
  [[ -n "$root" && -f "$root/.claude/agents/$type.md" ]] && team=1
fi

if (( team )); then
  running=$(ls "$slots" | wc -l | tr -d ' ')
  (( running >= ${CC_MAX_TEAM_AGENTS:-2} )) && deny "$running team agents running (cap ${CC_MAX_TEAM_AGENTS:-2}); wait for one to finish."
  : >"$slots/$type.$(date +%s).$RANDOM"
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

#!/usr/bin/env bash
# SessionStart: inside a Paseo-managed agent (PASEO_AGENT_ID set), add the attention
# lead-in format so the timeline-ui plugin renders answer points as attention cards.
# The literal must match ATTENTION_LEAD_IN_FORMAT in paseo-kit and pi-extensions contracts.
[[ -z "${PASEO_AGENT_ID:-}" ]] && exit 0
cat >/dev/null
jq -n '{hookSpecificOutput: {hookEventName: "SessionStart", additionalContext:
  "Format each distinct answer point as its own paragraph: **→ Lead-in.** Rest of the point."}}'

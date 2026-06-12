#!/usr/bin/env bash
# effort-classifier.sh — UserPromptSubmit hook.
# Classify prompt complexity → inject effort hint as additionalContext.
# Tiers: minimal | low | high | deep.
#
# Manual override: prefix prompt with one of:
#   !min   !low   !high   !deep   !auto (default classifier)
# Override is stripped from the hint reason for clarity.
set -euo pipefail

INPUT="$(cat)"
PROMPT="$(printf '%s' "$INPUT" | jq -r '.prompt // empty' 2>/dev/null || true)"

[ -z "$PROMPT" ] && exit 0

LEN=${#PROMPT}
LOWER="$(printf '%s' "$PROMPT" | tr '[:upper:]' '[:lower:]')"

tier=""
reason=""

# ---------- Manual override (highest priority) ----------
case "$LOWER" in
  !min\ *|!min|!minimal\ *|!minimal) tier="minimal"; reason="manual override (!min)" ;;
  !low\ *|!low)                       tier="low";     reason="manual override (!low)" ;;
  !high\ *|!high)                     tier="high";    reason="manual override (!high)" ;;
  !deep\ *|!deep)                     tier="deep";    reason="manual override (!deep)" ;;
  !auto\ *|!auto)                     ;;  # fall through to classifier
esac

# ---------- Auto classifier ----------
if [ -z "$tier" ]; then

  # DEEP — architectural / risky / multi-system
  if printf '%s' "$LOWER" | grep -Eq '\b(architecture|architect|redesign|migration|migrate.*(database|schema|prod)|refactor (whole|entire|all))\b'; then
    tier="deep"; reason="architectural scope"
  elif printf '%s' "$LOWER" | grep -Eq '\b(cross-?package|distributed|concurrency|race condition|deadlock|memory leak|performance regression|security audit|threat model|root cause)\b'; then
    tier="deep"; reason="systems/risk scope"
  elif printf '%s' "$LOWER" | grep -Eq '(^|\s)\.plan\b|\bplan this\b|\blet'\''s design\b|\bbrainstorm\b|\bspec this\b|\bwrite the spec\b|(^|\s)\.spec\b'; then
    tier="deep"; reason="planning/spec ask"
  elif printf '%s' "$LOWER" | grep -Eq '\b(production (bug|issue|incident)|broken in prod|p0|p1 bug|outage|postmortem)\b'; then
    tier="deep"; reason="production incident"

  # HIGH — feature / multi-file build / non-trivial refactor / debugging
  elif printf '%s' "$LOWER" | grep -Eq '\b(implement|build (a|the)|create (a|the) (component|feature|page|api|endpoint|service|skill|hook|plugin|command))\b'; then
    tier="high"; reason="feature build"
  elif printf '%s' "$LOWER" | grep -Eq '\b(refactor|extract|generalize|abstract|consolidate|deduplicate|introduce)\b'; then
    tier="high"; reason="refactor"
  elif printf '%s' "$LOWER" | grep -Eq '\b(multi.?file|across.*(files|modules|packages)|new module|new package)\b'; then
    tier="high"; reason="multi-file scope"
  elif printf '%s' "$LOWER" | grep -Eq '\b(review|audit) (this|the|my)\b|(^|\s)\.review\b|(^|\s)\.security\b'; then
    tier="high"; reason="review/audit"
  elif printf '%s' "$LOWER" | grep -Eq '\b(debug|investigate|trace|why is|why does|why am i|why isn'\''t|why won'\''t)\b'; then
    tier="high"; reason="debug/investigate"
  elif printf '%s' "$LOWER" | grep -Eq '\b(design (system|api|schema|data model)|optimize (query|algorithm|hot path))\b'; then
    tier="high"; reason="design/optimize"

  # MINIMAL — dot-commands, slash-commands, pure lookups
  elif printf '%s' "$LOWER" | grep -Eq '(^|\s)(\.worklog|\.recall|\.remember|\.stacks|\.docker|\.normal|\.caveman|\.write|\.ui|\.build|\.check)\b'; then
    tier="minimal"; reason="dot-command lookup"
  elif printf '%s' "$PROMPT" | grep -Eq '^/[a-zA-Z]'; then
    tier="minimal"; reason="slash-command"
  elif printf '%s' "$LOWER" | grep -Eq '^(give me|show me|list|what is|what'\''s|what are|get|fetch|find|grep|search for|tell me|how many|when is|what time|where is|what did i|hours for|worklog for|log hours|registration for|look up|check if|is the|is there|does .* (exist|have)|read (this|the)|print|display|output)\b'; then
    tier="minimal"; reason="lookup/list/format"
  elif printf '%s' "$LOWER" | grep -Eq '\b(memory|memories|engram|mcp|calendar|notes|reminders|contacts) (for|of|from|about|on)\b'; then
    tier="minimal"; reason="data fetch"
  elif printf '%s' "$LOWER" | grep -Eq '\b(can you (read|see|look at|check|verify|confirm))\b'; then
    tier="minimal"; reason="verification ask"

  # LOW — small targeted change, single-file edit, test, format (checked BEFORE short-fallback)
  elif printf '%s' "$LOWER" | grep -Eq '\b(rename|move|delete|remove|inline|add (a )?(comment|log|console|print)|fix typo|adjust|tweak|change (the )?(button|color|style|value|name|label)|update (the )?(comment|docstring|message|string|label|color|button))\b'; then
    tier="low"; reason="small targeted change"
  elif printf '%s' "$LOWER" | grep -Eq '\b(write|add) (a )?(test|unit test|spec)|run (the )?(tests?|build|lint|typecheck)\b'; then
    tier="low"; reason="test/build/lint"
  elif printf '%s' "$LOWER" | grep -Eq '\b(format|prettify|sort|reorder)\b'; then
    tier="low"; reason="format/sort"

  # MINIMAL fallback — short + no heavy verb (after LOW checks)
  elif [ "$LEN" -lt 60 ] && ! printf '%s' "$LOWER" | grep -Eq '\b(implement|build|refactor|design|fix|debug|review|migrate|optimize|test|rename|move|delete|change|update)\b'; then
    tier="minimal"; reason="short, no heavy verb"

  # DEFAULT — low (single-step assumed)
  else
    tier="low"; reason="default single-task scope"
  fi
fi

# ---------- Effort hint per tier ----------
case "$tier" in
  minimal) HINT="No tools. Direct answer." ;;
  low)     HINT="Single edit. No plan. Brief." ;;
  high)    HINT="Multi-file. Think. Surface tradeoffs." ;;
  deep)    HINT="Use planning-with-files. Confirm scope. Document decisions." ;;
esac

jq -nc \
  --arg ctx "[eff:$tier] $HINT" \
  '{hookSpecificOutput: {hookEventName: "UserPromptSubmit", additionalContext: $ctx}}'

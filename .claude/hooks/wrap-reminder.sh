#!/usr/bin/env bash
SESSION_ID=$(jq -r '.session_id // "unknown"' 2>/dev/null)
COUNTER_FILE="/tmp/claude-wrap-counter-${SESSION_ID}"

COUNT=$(cat "$COUNTER_FILE" 2>/dev/null || echo 0)
COUNT=$((COUNT + 1))
echo "$COUNT" > "$COUNTER_FILE"

if [ $((COUNT % 25)) -eq 0 ]; then
  echo "{\"systemMessage\": \"Turn $COUNT — run .wrap to save context before it bloats.\"}"
fi

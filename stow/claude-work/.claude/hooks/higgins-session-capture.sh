#!/bin/zsh
# SessionEnd hook: Higgins session capture for Claude Code sessions.
# Mirror of the pi session.idle tidy block in ~/.pi/agent/hook/hooks.yaml
# (daily-stamped digest + prune + compact + duckdb freshness).
# All failures no-op; never blocks the session shutdown.

IN=$(cat 2>/dev/null)
CWD=$(printf '%s' "$IN" | jq -r '.cwd // empty' 2>/dev/null)
[[ -n "$CWD" && -d "$CWD" ]] || exit 0
cd "$CWD" 2>/dev/null || exit 0

# Slug: let higgins resolve from cwd (same as `higgins status` does).
SLUG=$(higgins status 2>/dev/null | head -1 | cut -d' ' -f1)
[[ -n "$SLUG" ]] || SLUG=$(basename "$CWD")

# Daily-stamp guard: digest at most once per cwd per 24h.
STAMP_DIR="${TMPDIR:-/tmp}/higgins-tidy-claude"
STAMP="$STAMP_DIR/$SLUG.stamp"
mkdir -p "$STAMP_DIR" 2>/dev/null || true
if [[ -f "$STAMP" ]]; then
  LAST=$(cat "$STAMP" 2>/dev/null || echo 0)
  NOW=$(date +%s)
  AGE=$((NOW - LAST))
  [[ "$LAST" =~ ^[0-9]+$ ]] && [[ $AGE -lt 86400 ]] && exit 0
fi
printf '%s\n' "$(date +%s)" > "$STAMP" 2>/dev/null || true

higgins digest "$SLUG" --days 1 2>/dev/null || true
higgins prune "$SLUG" 2>/dev/null || true
higgins compact "$SLUG" 2>/dev/null || true

# DuckDB projection freshness (same guard as the pi side).
if higgins duckdb status 2>/dev/null | grep -q '"stale": true'; then
  higgins duckdb rebuild >/dev/null 2>&1 || true
fi

exit 0

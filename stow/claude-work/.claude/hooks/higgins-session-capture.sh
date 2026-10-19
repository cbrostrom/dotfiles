#!/bin/zsh
# SessionEnd hook: Higgins session capture for Claude Code sessions.
# Mirror of the pi session.idle tidy block in ~/.pi/agent/hook/hooks.yaml
# (same slug, same daily stamp dir, so the two harnesses share one run per day).
# Work runs detached; never blocks session shutdown.

IN=$(cat 2>/dev/null)
CWD=$(printf '%s' "$IN" | jq -r '.cwd // empty' 2>/dev/null)
[[ -n "$CWD" && -d "$CWD" ]] || exit 0
cd "$CWD" 2>/dev/null || exit 0

TOP=$(git rev-parse --show-toplevel 2>/dev/null)
SLUG=$(basename "${TOP:-$CWD}")

STAMP_DIR="${TMPDIR:-/tmp}/higgins-tidy"
STAMP="$STAMP_DIR/$SLUG.stamp"
mkdir -p "$STAMP_DIR" 2>/dev/null || true
if [[ -f "$STAMP" ]]; then
  LAST=$(cat "$STAMP" 2>/dev/null || echo 0)
  [[ "$LAST" =~ ^[0-9]+$ ]] && (( $(date +%s) - LAST < 86400 )) && exit 0
fi
printf '%s\n' "$(date +%s)" > "$STAMP" 2>/dev/null || true

(
  higgins digest "$SLUG" --days 1
  higgins prune "$SLUG"
  higgins compact "$SLUG"
  if higgins duckdb status | grep -q '"stale": true'; then
    higgins duckdb rebuild
  fi
) </dev/null >/dev/null 2>&1 &!

exit 0

#!/usr/bin/env bash
# Resolve the Paseo agent id for the current pi session.
# Emits the agent id (UUID) on stdout, or nothing if not a Paseo-spawned session.
# Reads only ~/.paseo state; no daemon calls, no locking, safe for hook use.
set -euo pipefail

project_dir="${PI_PROJECT_DIR:-$PWD}"

# Canonicalize best-effort (macOS: no realpath guarantee).
if command -v realpath >/dev/null 2>&1; then
  project_dir="$(realpath "$project_dir" 2>/dev/null || printf '%s' "$project_dir")"
fi

# Normalize trailing slash for string compare.
project_dir="${project_dir%/}"

agents_dir="${HOME}/.paseo/agents"
[[ -d "$agents_dir" ]] || exit 0

now=$(date +%s)

# Newest-first walk of workspace dirs; match agent record cwd to this session's project dir.
# Record mtime tracks Paseo's activity updates, so newest-mtime match = most likely current agent.
# Avoids find: bounded depth, few entries.
for ws in "$agents_dir"/*/; do
  [[ -d "$ws" ]] || continue
  for rec in $(ls -t "$ws"*.json 2>/dev/null); do
    [[ -f "$rec" ]] || continue
    # Extract cwd and updatedAt cheaply (no jq dependency requirement; fallback to grep).
    rec_cwd=$(grep -o '"cwd": *"[^"]*"' "$rec" 2>/dev/null | head -1 | sed 's/.*"cwd": *"\([^"]*\)".*/\1/')
    [[ -z "$rec_cwd" ]] && continue
    rec_cwd="${rec_cwd%/}"
    [[ "$rec_cwd" == "$project_dir" ]] || continue
    updated=$(grep -o '"updatedAt": *"[^"]*"' "$rec" 2>/dev/null | head -1 | sed 's/.*"updatedAt": *"\([^"]*\)".*/\1/')
    id=$(grep -o '"id": *"[^"]*"' "$rec" 2>/dev/null | head -1 | sed 's/.*"id": *"\([^"]*\)".*/\1/')
    [[ -z "$id" ]] && continue
    # Recency guard: record touched within last 14 days.
    if [[ -n "$updated" ]] && command -v python3 >/dev/null 2>&1; then
      age_s=$(python3 -c "
import sys, datetime
try:
    d = datetime.datetime.fromisoformat('$updated'.replace('Z', '+00:00'))
    print(max(0, int(datetime.datetime.now(datetime.timezone.utc).timestamp() - d.timestamp())))
except Exception:
    print(999999999)
" 2>/dev/null || echo 999999999)
      (( age_s < 1209600 )) || continue
    fi
    printf '%s\n' "$id"
    exit 0
  done
done

exit 0

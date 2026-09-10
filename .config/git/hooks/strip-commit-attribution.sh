#!/usr/bin/env bash
# Remove AI agent attribution from commit messages.
# Shared by prepare-commit-msg and commit-msg hooks.
set -euo pipefail

COMMIT_MSG_FILE="${1:?usage: strip-commit-attribution.sh <commit-msg-file>}"
[[ -f "$COMMIT_MSG_FILE" ]] || exit 0

awk '
function lower(s) {
  return tolower(s)
}

function is_attribution_line(line) {
  l = lower(line)
  if (l ~ /^[[:space:]]*made with cursor[[:space:]]*$/) return 1
  if (l ~ /^[[:space:]]*made-with:[[:space:]]*/) return 1
  if (l ~ /^[[:space:]]*co-authored-by:.*cursor/) return 1
  if (l ~ /^[[:space:]]*co-authored-by:.*@cursor\.sh/) return 1
  if (l ~ /^[[:space:]]*co-authored-by:.*noreply@cursor/) return 1
  if (l ~ /^[[:space:]]*co-authored-by:.*cursoragent/) return 1
  if (l ~ /^[[:space:]]*signed-off-by:.*cursor/) return 1
  return 0
}

{
  lines[NR] = $0
}

END {
  for (i = 1; i <= NR; i++) {
    if (!is_attribution_line(lines[i])) {
      keep[i] = 1
    }
  }

  # Drop trailing --- separators and blank lines left after attribution removal.
  for (i = NR; i >= 1; i--) {
    if (!(i in keep)) continue
    if (lines[i] ~ /^[[:space:]]*---[[:space:]]*$/) {
      delete keep[i]
    } else if (lines[i] ~ /^[[:space:]]*$/) {
      delete keep[i]
    } else {
      break
    }
  }

  last = 0
  for (i = 1; i <= NR; i++) {
    if (i in keep) last = i
  }

  for (i = 1; i <= last; i++) {
    if (i in keep) print lines[i]
  }
}
' "$COMMIT_MSG_FILE" > "${COMMIT_MSG_FILE}.stripped"

mv "${COMMIT_MSG_FILE}.stripped" "$COMMIT_MSG_FILE"

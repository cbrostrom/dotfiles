#!/usr/bin/env bash
# brain-save-inject.sh — PreCompact + UserPromptSubmit hook
# Injects instruction to write .claude/brain.md before context is lost.
# As PreCompact: always fires.
# As UserPromptSubmit: fires only on /compact or /clear.
set -uo pipefail

if [[ "${HOOK_EVENT_NAME:-}" == "UserPromptSubmit" ]]; then
  INPUT="$(cat)"
  PROMPT="$(printf '%s' "$INPUT" | jq -r '.prompt // empty' 2>/dev/null || true)"
  [ -z "$PROMPT" ] && exit 0
  printf '%s' "$PROMPT" | grep -qE '^\s*/(compact|clear)\b' || exit 0
else
  cat >/dev/null
fi

git rev-parse --git-dir >/dev/null 2>&1 || exit 0

BRAIN=".claude/brain.md"
REPO="$(basename "$(git rev-parse --show-toplevel 2>/dev/null)" 2>/dev/null || echo "unknown")"
NOW="$(date '+%Y-%m-%d %H:%M')"

cat <<EOF
=== BRAIN SAVE REQUIRED ===
Context about to compact/clear. Write ${BRAIN} NOW before proceeding.
Project: ${REPO} | Timestamp: ${NOW}

Write with these exact sections (≤3 bullets each, no filler):

# Brain: ${REPO}
_Updated: ${NOW}_

## Current State
- [what we're actively doing right now]

## Open Decisions
- [unresolved choices/questions from this session]

## Gotchas
- [non-obvious things discovered this session]

## Next Steps
- [concrete first action for next session]

## Git Snapshot
[output of: git diff --stat HEAD (or HEAD~1 if nothing staged)]

After writing brain.md, proceed with the compact/clear.
=== END BRAIN SAVE REQUIRED ===
EOF

exit 0

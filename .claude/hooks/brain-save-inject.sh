#!/usr/bin/env bash
# brain-save-inject.sh — PreCompact + UserPromptSubmit hook
# Injects instruction to write ~/Vaults/Brain/Brains/<slug>.md before context is lost.
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

# Slug: git repo basename if in a repo, else PWD basename
if git rev-parse --git-dir >/dev/null 2>&1; then
  SLUG="$(basename "$(git rev-parse --show-toplevel 2>/dev/null)")"
else
  SLUG="$(basename "$PWD")"
fi

# Platform detection
if grep -qi microsoft /proc/version 2>/dev/null || [[ -n "${WSL_DISTRO_NAME:-}" ]]; then
  VAULT_BRAINS="/mnt/c/Users/christian/Obsidian/Brain/Brains"
else
  VAULT_BRAINS="$HOME/Vaults/Brain/Brains"
fi
BRAIN="${VAULT_BRAINS}/${SLUG}.md"
NOW="$(date '+%Y-%m-%d %H:%M')"

# Git snapshot line (optional — omitted if not a git repo)
GIT_SNAP=""
if git rev-parse --git-dir >/dev/null 2>&1; then
  GIT_SNAP="$(git diff --stat HEAD 2>/dev/null || git diff --stat HEAD~1 2>/dev/null || true)"
fi

cat <<EOF
=== BRAIN SAVE REQUIRED ===
Context about to compact/clear. Write ${BRAIN} NOW before proceeding.
Project: ${SLUG} | Timestamp: ${NOW}

Write with these exact sections (≤3 bullets each, no filler):

# Brain: ${SLUG}
_Updated: ${NOW}_

## Current State
- [what we're actively doing right now]

## Open Decisions
- [unresolved choices/questions from this session]

## Gotchas
- [non-obvious things discovered this session]

## Next Steps
- [concrete first action for next session]
${GIT_SNAP:+
## Git Snapshot
${GIT_SNAP}}

After writing the brain file, proceed with the compact/clear.
=== END BRAIN SAVE REQUIRED ===
EOF

exit 0

#!/usr/bin/env bash
# brain-load.sh — SessionStart hook
# If .claude/brain.md exists in $PWD, inject it as session context.
set -uo pipefail

BRAIN=".claude/brain.md"
[ -f "$BRAIN" ] || exit 0

if [[ "$(uname)" == "Darwin" ]]; then
  MOD="$(stat -f "%Sm" -t "%Y-%m-%d %H:%M" "$BRAIN" 2>/dev/null || true)"
else
  MOD="$(stat -c "%y" "$BRAIN" 2>/dev/null | cut -d'.' -f1 || true)"
fi

cat <<EOF
=== PROJECT BRAIN LOADED ===
Source: ${BRAIN} (last written: ${MOD:-unknown})
$(cat "$BRAIN")
=== END PROJECT BRAIN ===
EOF

exit 0

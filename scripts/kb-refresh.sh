#!/usr/bin/env bash
# kb-refresh.sh — human-run monthly vault hygiene workflow
# NEVER run from cron. Run manually after kb-review.sh reports action needed.
# Logs all output to _ops/janitor-logs/kb-refresh-DATE-HOSTNAME.log

set -euo pipefail

VAULT_AI="${VAULT_AI:-$HOME/Vaults/Higgins/AI}"
TODAY=$(date +%Y-%m-%d)
HOSTNAME_SHORT=$(hostname -s)
LOG_DIR="$VAULT_AI/_ops/janitor-logs"
REFRESH_LOG="$LOG_DIR/kb-refresh-${TODAY}-${HOSTNAME_SHORT}.log"
REVIEW_SCRIPT="$(dirname "$0")/kb-review.sh"

mkdir -p "$LOG_DIR"

# Tee all output to log file
exec > >(tee "$REFRESH_LOG") 2>&1

echo "=== Monthly KB Refresh — $TODAY ==="
echo "Log: $REFRESH_LOG"
echo ""

# ── Step 1: Run review scan ───────────────────────────────────────────────────

if [ ! -f "$REVIEW_SCRIPT" ]; then
  echo "ERROR: kb-review.sh not found at $REVIEW_SCRIPT"
  exit 1
fi

set +e
bash "$REVIEW_SCRIPT"
REVIEW_EXIT=$?
set -e

echo ""

if [ "$REVIEW_EXIT" -eq 0 ]; then
  echo "Nothing stale — all entries current. Checklist still recommended:"
fi

# ── Step 2: Print checklist ───────────────────────────────────────────────────

cat << 'CHECKLIST'
REVIEW CHECKLIST:

GOTCHAS — for each STALE entry in personal/gotchas.md:
  → ACTIVE:   Update "- Renewed: YYYY-MM-DD" to today's date
  → RESOLVED: Add "- Resolved: YYYY-MM-DD" and "- Resolution note: ..."
  → OBSOLETE: Change Status to RESOLVED, add note "obsolete — no longer applies"

DECISIONS — for each OVERDUE entry in personal/decisions.md:
  → VALIDATED:  Write outcome, change Status to VALIDATED, add "- Validated: YYYY-MM-DD"
  → REVERSED:   Write what went wrong, change Status to REVERSED (keep entry, never delete)
  → SUPERSEDED: Add "- Superseded by: [D-NNN]", change Status to SUPERSEDED

AFTER EDITING — run these manually:
  $ kb compact personal
    (writes monthly snapshot to personal/history/, trims current.md to ≤5 bullets)

  $ kb digest
    (scans recent sessions, proposes gotcha/decision updates — optional but recommended)

CHECKLIST

# ── Step 3: Offer editor ──────────────────────────────────────────────────────

echo "FILES TO EDIT:"
echo "  $VAULT_AI/personal/gotchas.md"
echo "  $VAULT_AI/personal/decisions.md"
echo ""

if [ -n "${EDITOR:-}" ] && [ -t 0 ]; then
  printf "Open in \$EDITOR (%s)? [y/N] " "$EDITOR"
  read -r answer
  if [ "$answer" = "y" ] || [ "$answer" = "Y" ]; then
    "$EDITOR" "$VAULT_AI/personal/gotchas.md" "$VAULT_AI/personal/decisions.md"
  fi
else
  echo "(\$EDITOR not set or no TTY — open files manually)"
fi

echo ""
echo "Refresh complete. Log saved: $REFRESH_LOG"

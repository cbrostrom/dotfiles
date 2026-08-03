#!/usr/bin/env bash
# kb-review.sh — non-interactive vault health scan
# Exit 0: all current. Exit 1: action needed.
# Usage: kb-review.sh
# Runs from cron (monthly) and manually. Read-only: never modifies vault files.

set -euo pipefail

VAULT_AI="${VAULT_AI:-$HOME/Vaults/Higgins/AI}"
TODAY=$(date +%Y-%m-%d)
GOTCHAS_FILE="$VAULT_AI/personal/gotchas.md"
DECISIONS_FILE="$VAULT_AI/personal/decisions.md"

STALE_RENEWAL_DAYS=30
RESOLVED_ARCHIVE_DAYS=90
ACTION_NEEDED=0

# ── Shared utilities ──────────────────────────────────────────────────────────

# Returns days since YYYY-MM-DD. Returns 9999 on unparseable date (treats as very old).
days_since() {
  local d="$1"
  local ts
  if [[ "$OSTYPE" == "darwin"* ]]; then
    ts=$(date -j -f%Y-%m-%d "$d" +%s 2>/dev/null) || { echo 9999; return; }
  else
    ts=$(date -d "$d" +%s 2>/dev/null) || { echo 9999; return; }
  fi
  echo $(( ($(date +%s) - ts) / 86400 ))
}

# Returns 0 (true) if date is in the past. Returns 0 on unparseable (safe: treat as past).
date_is_past() {
  local d="$1"
  local ts today
  today=$(date +%s)
  if [[ "$OSTYPE" == "darwin"* ]]; then
    ts=$(date -j -f%Y-%m-%d "$d" +%s 2>/dev/null) || return 0
  else
    ts=$(date -d "$d" +%s 2>/dev/null) || return 0
  fi
  [ "$ts" -lt "$today" ]
}

# Outputs one line per ACTIVE/WATCH entry: ID|STATUS|RENEWED|TITLE
# Stops at --- divider — ignores ## Resolved section entirely.
# Skips entries without [G-NNN] format (old format — graceful degradation).
parse_gotchas() {
  local file="$1"
  awk '
    /^---/ { exit }
    BEGIN { id=""; title=""; status=""; renewed="" }
    /^## \[G-[0-9]+\]/ {
      if (id != "") print id "|" status "|" renewed "|" title
      match($0, /\[G-[0-9]+\]/)
      id     = substr($0, RSTART, RLENGTH)
      title  = substr($0, RSTART + RLENGTH + 1)
      status  = "UNKNOWN"
      renewed = "1970-01-01"
    }
    /^- Status: /  { status  = substr($0, 11) }
    /^- Renewed: / { renewed = substr($0, 12) }
    END { if (id != "") print id "|" status "|" renewed "|" title }
  ' "$file"
}

# Outputs one line per entry: ID|STATUS|VALIDATE_BY|TITLE
parse_decisions() {
  local file="$1"
  awk '
    BEGIN { id=""; title=""; status=""; validate_by="" }
    /^## \[D-[0-9]+\]/ {
      if (id != "") print id "|" status "|" validate_by "|" title
      match($0, /\[D-[0-9]+\]/)
      id          = substr($0, RSTART, RLENGTH)
      title       = substr($0, RSTART + RLENGTH + 1)
      status      = "UNKNOWN"
      validate_by = "1970-01-01"
    }
    /^- Status: /      { status      = substr($0, 11) }
    /^- Validate by: / { validate_by = substr($0, 16) }
    END { if (id != "") print id "|" status "|" validate_by "|" title }
  ' "$file"
}

# ── Gotchas scan ──────────────────────────────────────────────────────────────

echo "=== KB Review — $TODAY ==="
echo ""

if [ ! -f "$GOTCHAS_FILE" ]; then
  echo "WARNING: gotchas.md not found at $GOTCHAS_FILE"
else
  G_TOTAL=0; G_ACTIVE=0; G_WATCH=0; G_RESOLVED=0
  G_NEXT_NUM=0
  G_STALE_ENTRIES=()    # each element: "ID|RENEWED|AGE_DAYS|TITLE"
  G_ARCHIVE_ENTRIES=()  # each element: "ID|TITLE"

  while IFS='|' read -r gid status renewed title; do
    G_TOTAL=$((G_TOTAL + 1))
    num="${gid//[^0-9]/}"
    [ "$num" -gt "$G_NEXT_NUM" ] && G_NEXT_NUM="$num"

    case "$status" in
      ACTIVE)   G_ACTIVE=$((G_ACTIVE + 1)) ;;
      WATCH)    G_WATCH=$((G_WATCH + 1)) ;;
      RESOLVED) G_RESOLVED=$((G_RESOLVED + 1)) ;;
    esac

    age=$(days_since "$renewed")

    if [ "$status" != "RESOLVED" ] && [ "$age" -gt "$STALE_RENEWAL_DAYS" ]; then
      G_STALE_ENTRIES+=("${gid}|${renewed}|${age}|${title}")
      ACTION_NEEDED=1
    fi

    if [ "$status" = "RESOLVED" ] && [ "$age" -gt "$RESOLVED_ARCHIVE_DAYS" ]; then
      G_ARCHIVE_ENTRIES+=("${gid}|${title}")
      ACTION_NEEDED=1
    fi
  done < <(parse_gotchas "$GOTCHAS_FILE")

  G_NEXT_NUM=$((G_NEXT_NUM + 1))
  G_NEXT_ID_FMT=$(printf "G-%03d" "$G_NEXT_NUM")

  echo "GOTCHAS: $G_TOTAL total | $G_ACTIVE active | $G_WATCH watch | $G_RESOLVED resolved"

  if [ ${#G_STALE_ENTRIES[@]} -gt 0 ]; then
    echo "  STALE (not renewed >${STALE_RENEWAL_DAYS}d):"
    for entry in "${G_STALE_ENTRIES[@]}"; do
      IFS='|' read -r gid renewed age title <<< "$entry"
      echo "    $gid — $title (renewed: $renewed, ${age}d ago)"
    done
  fi

  if [ ${#G_ARCHIVE_ENTRIES[@]} -gt 0 ]; then
    echo "  ARCHIVE CANDIDATES (resolved >${RESOLVED_ARCHIVE_DAYS}d):"
    for entry in "${G_ARCHIVE_ENTRIES[@]}"; do
      IFS='|' read -r gid title <<< "$entry"
      echo "    $gid — $title"
    done
  fi

  if [ ${#G_STALE_ENTRIES[@]} -eq 0 ] && [ ${#G_ARCHIVE_ENTRIES[@]} -eq 0 ]; then
    echo "  All gotchas current."
  fi

  echo "  Next available ID: $G_NEXT_ID_FMT"
fi

echo ""

# ── Decisions scan ────────────────────────────────────────────────────────────

if [ ! -f "$DECISIONS_FILE" ]; then
  echo "WARNING: decisions.md not found at $DECISIONS_FILE"
else
  D_TOTAL=0; D_PENDING=0; D_VALIDATED=0; D_REVERSED=0; D_SUPERSEDED=0
  D_NEXT_NUM=0
  D_OVERDUE_ENTRIES=()  # each element: "ID|VALIDATE_BY|OVERDUE_DAYS|TITLE"

  while IFS='|' read -r did status validate_by title; do
    D_TOTAL=$((D_TOTAL + 1))
    num="${did//[^0-9]/}"
    [ "$num" -gt "$D_NEXT_NUM" ] && D_NEXT_NUM="$num"

    case "$status" in
      PENDING)    D_PENDING=$((D_PENDING + 1)) ;;
      VALIDATED)  D_VALIDATED=$((D_VALIDATED + 1)) ;;
      REVERSED)   D_REVERSED=$((D_REVERSED + 1)) ;;
      SUPERSEDED) D_SUPERSEDED=$((D_SUPERSEDED + 1)) ;;
    esac

    # Skip ONGOING — those never expire
    if [ "$status" = "PENDING" ] && [ "$validate_by" != "ONGOING" ]; then
      if date_is_past "$validate_by"; then
        overdue=$(days_since "$validate_by")
        D_OVERDUE_ENTRIES+=("${did}|${validate_by}|${overdue}|${title}")
        ACTION_NEEDED=1
      fi
    fi
  done < <(parse_decisions "$DECISIONS_FILE")

  D_NEXT_NUM=$((D_NEXT_NUM + 1))
  D_NEXT_ID_FMT=$(printf "D-%03d" "$D_NEXT_NUM")

  echo "DECISIONS: $D_TOTAL total | $D_PENDING pending | $D_VALIDATED validated | $D_REVERSED reversed"

  if [ ${#D_OVERDUE_ENTRIES[@]} -gt 0 ]; then
    echo "  OVERDUE VALIDATION:"
    for entry in "${D_OVERDUE_ENTRIES[@]}"; do
      IFS='|' read -r did validate_by overdue title <<< "$entry"
      echo "    $did — $title (validate by: $validate_by, ${overdue}d overdue)"
    done
  else
    echo "  All decisions current."
  fi

  echo "  Next available ID: $D_NEXT_ID_FMT"
fi

echo ""

# ── Result ────────────────────────────────────────────────────────────────────

if [ "$ACTION_NEEDED" -eq 1 ]; then
  echo "ACTION NEEDED — run: kb-refresh.sh"
  exit 1
else
  echo "All entries current — no action needed."
  exit 0
fi

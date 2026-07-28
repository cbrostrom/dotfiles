# KB Evolution Plan v2 — Haiku Implementation Spec
> Status: READY FOR IMPLEMENTATION
> Model: Haiku
> Reviewed: Adversarial pass completed, all issues resolved
> Sync: Syncthing only (no git involvement in vault)
> Cycle: Monthly

---

## ARCHITECTURE DECISION: WIKI MODEL

gotchas.md and decisions.md are **editable living documents** (wiki pages).
They are NOT append-only.

Protection against data loss comes from:
1. Monthly snapshots → `personal/history/` (written by kb compact)
2. Syncthing → redundant copy on all devices
3. Janitor line-count floor → detects bulk deletion, does not block edits

history/ files ARE immutable. Never edited after creation.

---

## CONTEXT

```
Vault AI root:  ~/Vaults/Higgins/AI/         → env: $VAULT_AI (default if unset)
Scripts:        ~/dotfiles/scripts/
Janitor script: ~/dotfiles/scripts/janitor.sh
Log dir:        ~/Vaults/Higgins/AI/_ops/janitor-logs/
Report dir:     ~/Vaults/Higgins/AI/_ops/janitor-logs/reports/
Gotchas:        ~/Vaults/Higgins/AI/personal/gotchas.md
Decisions:      ~/Vaults/Higgins/AI/personal/decisions.md
Snapshots:      ~/Vaults/Higgins/AI/personal/history/
```

---

## WHAT TO BUILD

1. Format spec for gotchas.md and decisions.md (this document defines it)
2. `kb-review.sh` — non-interactive scanner, exit 1 if action needed
3. `kb-refresh.sh` — human-run monthly workflow (never run from cron)
4. Janitor patch — add `kb_health` section to nightly health JSON
5. Cron entries — kb-review.sh only, both Mac and SuperBro

**DO NOT:**
- Auto-modify gotchas.md or decisions.md
- Run kb-refresh.sh from cron (it is human-only)
- Touch history/ files
- Use git for anything
- Add dependencies beyond bash + awk + grep + sed + date

---

## 1. FORMAT SPEC: gotchas.md

### File header (top of file, keep this):
```markdown
# Personal Gotchas
> Format spec: ~/dotfiles/docs/kb-evolution-plan-v2.md
> Status values: ACTIVE | WATCH | RESOLVED
> Edit in-place. Monthly snapshot via: kb compact personal

```

### Entry template:
```markdown
## [G-NNN] Short title
- Added: YYYY-MM-DD
- Status: ACTIVE
- Renewed: YYYY-MM-DD
- Trap: One sentence — what goes wrong
- Fix: One sentence — what to do about it
```

### Status values (exactly 3):
- `ACTIVE` — still biting, watch out
- `WATCH` — probably fixed but not confirmed yet
- `RESOLVED` — confirmed fixed, keep until next snapshot then archive

### When resolving an entry, EDIT in-place (add two fields):
```markdown
## [G-NNN] Short title
- Added: YYYY-MM-DD
- Status: RESOLVED
- Renewed: YYYY-MM-DD
- Resolved: YYYY-MM-DD
- Trap: One sentence
- Fix: One sentence
- Resolution note: What confirmed it is fixed
```

### Staleness thresholds:
- `Renewed` date > 30 days ago → flagged STALE by kb-review.sh
- `Status: RESOLVED` AND `Resolved` date > 90 days ago → flagged ARCHIVE CANDIDATE

### ID assignment rule:
No counter file. Next ID = highest existing [G-NNN] number + 1.
kb-review.sh prints "Next available: G-NNN" at the bottom of each run.
If two machines assign the same ID before sync: Syncthing flags conflict.
Janitor detects .sync-conflict-* files → alerts in health report (already implemented).

### Complete example:
```markdown
## [G-001] pfctl rule order resets on macOS update
- Added: 2026-06-01
- Status: ACTIVE
- Renewed: 2026-07-28
- Trap: rdr-anchor must precede anchor in /etc/pf.conf — macOS updates silently reset this
- Fix: sudo scripts/system/pf-caddy.sh after any macOS update
```

---

## 2. FORMAT SPEC: decisions.md

### File header (top of file, keep this):
```markdown
# Personal Decisions
> Format spec: ~/dotfiles/docs/kb-evolution-plan-v2.md
> Status values: PENDING | VALIDATED | REVERSED | SUPERSEDED
> Edit in-place. Monthly snapshot via: kb compact personal

```

### Entry template:
```markdown
## [D-NNN] Short decision title
- Decided: YYYY-MM-DD
- Status: PENDING
- Hypothesis: Why this is the right call
- Success criteria: Measurable outcome that confirms it
- Validate by: YYYY-MM-DD
- Outcome: —
```

### Status values (exactly 4):
- `PENDING` — decided, not yet validated
- `VALIDATED` — hypothesis confirmed, outcome written
- `REVERSED` — wrong, reverted. Keep as lesson. Never delete.
- `SUPERSEDED` — replaced. Add "Superseded by: [D-NNN]" field.

### For permanent architectural decisions with no expiry:
```
- Validate by: ONGOING
```
kb-review.sh and janitor skip ONGOING entries.

### When validating, EDIT in-place:
```markdown
## [D-NNN] Short decision title
- Decided: YYYY-MM-DD
- Status: VALIDATED
- Hypothesis: Why we thought this was right
- Success criteria: Measurable outcome
- Validate by: YYYY-MM-DD
- Validated: YYYY-MM-DD
- Outcome: What happened. Was hypothesis correct? One short paragraph.
```

### ID assignment: same rule as gotchas — max existing + 1, kb-review prints next available.

### Complete example:
```markdown
## [D-001] Syncthing over rsync for vault sync
- Decided: 2026-07-28
- Status: PENDING
- Hypothesis: Automatic conflict detection, works across Linux and macOS without cron
- Success criteria: Zero data loss, conflict count visible in janitor health report
- Validate by: 2026-09-28
- Outcome: —
```

---

## 3. SHARED BASH FUNCTIONS

These functions are used in BOTH kb-review.sh and janitor.sh.
Define them at the top of each script (copy, do not source — avoids dependency).

### Cross-platform date utilities:
```bash
# Cross-platform days since a date (YYYY-MM-DD)
# Returns 9999 if date is unparseable (treats as very old = safe to flag)
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

# Cross-platform: is date in the past? Returns 0 (true) or 1 (false)
date_is_past() {
  local d="$1"
  local ts today
  today=$(date +%s)
  if [[ "$OSTYPE" == "darwin"* ]]; then
    ts=$(date -j -f%Y-%m-%d "$d" +%s 2>/dev/null) || return 0  # unparseable = treat as past
  else
    ts=$(date -d "$d" +%s 2>/dev/null) || return 0
  fi
  [ "$ts" -lt "$today" ]
}

# Cross-platform: date + N days → YYYY-MM-DD
date_add_days() {
  local d="$1" n="$2"
  if [[ "$OSTYPE" == "darwin"* ]]; then
    date -v+${n}d -j -f%Y-%m-%d "$d" +%Y-%m-%d 2>/dev/null || echo "unknown"
  else
    date -d "$d + $n days" +%Y-%m-%d 2>/dev/null || echo "unknown"
  fi
}
```

### Gotcha file parser (awk):
Outputs one line per entry: `ID|STATUS|RENEWED|TITLE`
Skips entries without [G-NNN] format (old-format entries — graceful degradation).
```bash
parse_gotchas() {
  local file="$1"
  awk '
    BEGIN { id=""; title=""; status=""; renewed="" }
    /^## \[G-[0-9]+\]/ {
      if (id != "") print id "|" status "|" renewed "|" title
      match($0, /\[G-[0-9]+\]/)
      id = substr($0, RSTART, RLENGTH)
      title = substr($0, RSTART + length(id) + 2)
      status = "UNKNOWN"; renewed = "1970-01-01"
    }
    /^- Status: /  { status  = substr($0, 11) }
    /^- Renewed: / { renewed = substr($0, 12) }
    END { if (id != "") print id "|" status "|" renewed "|" title }
  ' "$file"
}
```

### Decision file parser (awk):
Outputs one line per entry: `ID|STATUS|VALIDATE_BY|TITLE`
```bash
parse_decisions() {
  local file="$1"
  awk '
    BEGIN { id=""; title=""; status=""; validate_by="" }
    /^## \[D-[0-9]+\]/ {
      if (id != "") print id "|" status "|" validate_by "|" title
      match($0, /\[D-[0-9]+\]/)
      id = substr($0, RSTART, RLENGTH)
      title = substr($0, RSTART + length(id) + 2)
      status = "UNKNOWN"; validate_by = "1970-01-01"
    }
    /^- Status: /      { status      = substr($0, 11) }
    /^- Validate by: / { validate_by = substr($0, 16) }
    END { if (id != "") print id "|" status "|" validate_by "|" title }
  ' "$file"
}
```

### JSON array builder:
```bash
# Converts space-separated list to JSON array: "G-001 G-003" → ["G-001","G-003"]
to_json_array() {
  local items="$1"
  if [ -z "$items" ]; then echo "[]"; return; fi
  local json="["
  local first=true
  for item in $items; do
    [ "$first" = true ] && json="${json}\"$item\"" || json="${json},\"$item\""
    first=false
  done
  echo "${json}]"
}
```

---

## 4. kb-review.sh

### Location: `~/dotfiles/scripts/kb-review.sh`
### Purpose: Non-interactive scan. Reports stale gotchas and overdue decisions.
### Exit code: 0 = all current, 1 = action needed

```bash
#!/usr/bin/env bash
set -euo pipefail

VAULT_AI="${VAULT_AI:-$HOME/Vaults/Higgins/AI}"
TODAY=$(date +%Y-%m-%d)
GOTCHAS_FILE="$VAULT_AI/personal/gotchas.md"
DECISIONS_FILE="$VAULT_AI/personal/decisions.md"

STALE_RENEWAL_DAYS=30
RESOLVED_ARCHIVE_DAYS=90

ACTION_NEEDED=0

# --- [include all shared functions here: days_since, date_is_past, parse_gotchas, parse_decisions, to_json_array] ---

echo "=== KB Review — $TODAY ==="
echo ""

# ---- GOTCHAS ----
if [ ! -f "$GOTCHAS_FILE" ]; then
  echo "WARNING: gotchas.md not found at $GOTCHAS_FILE"
else
  G_TOTAL=0; G_ACTIVE=0; G_WATCH=0; G_RESOLVED=0
  G_STALE_IDS=""; G_ARCHIVE_IDS=""
  G_NEXT_ID=1

  while IFS='|' read -r gid status renewed title; do
    G_TOTAL=$((G_TOTAL + 1))
    # Track max ID for next-available calculation
    num="${gid//[^0-9]/}"
    [ "$num" -gt "$((G_NEXT_ID - 1))" ] && G_NEXT_ID=$((num + 1))

    case "$status" in
      ACTIVE) G_ACTIVE=$((G_ACTIVE + 1)) ;;
      WATCH)  G_WATCH=$((G_WATCH + 1)) ;;
      RESOLVED) G_RESOLVED=$((G_RESOLVED + 1)) ;;
    esac

    # Check staleness
    age=$(days_since "$renewed")
    if [ "$age" -gt "$STALE_RENEWAL_DAYS" ] && [ "$status" != "RESOLVED" ]; then
      G_STALE_IDS="$G_STALE_IDS $gid"
      ACTION_NEEDED=1
    fi

    # Check resolved archive candidates (need Resolved date — parse separately)
    # For simplicity: flag RESOLVED entries where Renewed is >90 days old
    if [ "$status" = "RESOLVED" ] && [ "$age" -gt "$RESOLVED_ARCHIVE_DAYS" ]; then
      G_ARCHIVE_IDS="$G_ARCHIVE_IDS $gid"
      ACTION_NEEDED=1
    fi
  done < <(parse_gotchas "$GOTCHAS_FILE")

  G_NEXT_ID_FMT=$(printf "G-%03d" "$G_NEXT_ID")

  echo "GOTCHAS: $G_TOTAL total | $G_ACTIVE active | $G_WATCH watch | $G_RESOLVED resolved"

  if [ -n "$G_STALE_IDS" ]; then
    echo "  STALE (not renewed >${STALE_RENEWAL_DAYS}d):"
    for gid in $G_STALE_IDS; do
      # re-parse to get title and age for display
      entry=$(parse_gotchas "$GOTCHAS_FILE" | grep "^${gid}|")
      title=$(echo "$entry" | cut -d'|' -f4)
      renewed=$(echo "$entry" | cut -d'|' -f3)
      age=$(days_since "$renewed")
      echo "    $gid — $title (renewed: $renewed, ${age}d ago)"
    done
  fi

  if [ -n "$G_ARCHIVE_IDS" ]; then
    echo "  ARCHIVE CANDIDATES (resolved >${RESOLVED_ARCHIVE_DAYS}d):"
    for gid in $G_ARCHIVE_IDS; do
      entry=$(parse_gotchas "$GOTCHAS_FILE" | grep "^${gid}|")
      title=$(echo "$entry" | cut -d'|' -f4)
      echo "    $gid — $title"
    done
  fi

  if [ -z "$G_STALE_IDS" ] && [ -z "$G_ARCHIVE_IDS" ]; then
    echo "  All gotchas current."
  fi

  echo "  Next available ID: $G_NEXT_ID_FMT"
fi

echo ""

# ---- DECISIONS ----
if [ ! -f "$DECISIONS_FILE" ]; then
  echo "WARNING: decisions.md not found at $DECISIONS_FILE"
else
  D_TOTAL=0; D_PENDING=0; D_VALIDATED=0; D_REVERSED=0; D_SUPERSEDED=0
  D_OVERDUE_IDS=""
  D_NEXT_ID=1

  while IFS='|' read -r did status validate_by title; do
    D_TOTAL=$((D_TOTAL + 1))
    num="${did//[^0-9]/}"
    [ "$num" -gt "$((D_NEXT_ID - 1))" ] && D_NEXT_ID=$((num + 1))

    case "$status" in
      PENDING)    D_PENDING=$((D_PENDING + 1)) ;;
      VALIDATED)  D_VALIDATED=$((D_VALIDATED + 1)) ;;
      REVERSED)   D_REVERSED=$((D_REVERSED + 1)) ;;
      SUPERSEDED) D_SUPERSEDED=$((D_SUPERSEDED + 1)) ;;
    esac

    # Flag overdue: PENDING + validate_by is in the past + not ONGOING
    if [ "$status" = "PENDING" ] && [ "$validate_by" != "ONGOING" ]; then
      if date_is_past "$validate_by"; then
        overdue_days=$(days_since "$validate_by")
        D_OVERDUE_IDS="$D_OVERDUE_IDS $did"
        ACTION_NEEDED=1
      fi
    fi
  done < <(parse_decisions "$DECISIONS_FILE")

  D_NEXT_ID_FMT=$(printf "D-%03d" "$D_NEXT_ID")

  echo "DECISIONS: $D_TOTAL total | $D_PENDING pending | $D_VALIDATED validated | $D_REVERSED reversed"

  if [ -n "$D_OVERDUE_IDS" ]; then
    echo "  OVERDUE VALIDATION:"
    for did in $D_OVERDUE_IDS; do
      entry=$(parse_decisions "$DECISIONS_FILE" | grep "^${did}|")
      title=$(echo "$entry" | cut -d'|' -f4)
      validate_by=$(echo "$entry" | cut -d'|' -f3)
      overdue=$(days_since "$validate_by")
      echo "    $did — $title (validate by: $validate_by, ${overdue}d overdue)"
    done
  fi

  if [ -z "$D_OVERDUE_IDS" ]; then
    echo "  All decisions current."
  fi

  echo "  Next available ID: $D_NEXT_ID_FMT"
fi

echo ""

if [ "$ACTION_NEEDED" -eq 1 ]; then
  echo "ACTION NEEDED — run: kb-refresh.sh"
  exit 1
else
  echo "All entries current — no action needed."
  exit 0
fi
```

---

## 5. kb-refresh.sh

### Location: `~/dotfiles/scripts/kb-refresh.sh`
### Purpose: Human-run monthly workflow. Never run from cron.
### NOT interactive in the sense of waiting for input mid-script.
### Opens files in $EDITOR at the end only.

```bash
#!/usr/bin/env bash
set -euo pipefail

VAULT_AI="${VAULT_AI:-$HOME/Vaults/Higgins/AI}"
TODAY=$(date +%Y-%m-%d)
HOSTNAME=$(hostname -s)
LOG_DIR="$VAULT_AI/_ops/janitor-logs"
REFRESH_LOG="$LOG_DIR/kb-refresh-${TODAY}-${HOSTNAME}.log"
KB_BIN="${KB_BIN:-$HOME/dotfiles/scripts/kb}"

mkdir -p "$LOG_DIR"

# Tee all output to log file
exec > >(tee "$REFRESH_LOG") 2>&1

echo "=== Monthly KB Refresh — $TODAY ==="
echo "Log: $REFRESH_LOG"
echo ""

# Step 1: Run review
REVIEW_SCRIPT="$(dirname "$0")/kb-review.sh"
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
  echo "Nothing stale. Checklist still recommended:"
fi

# Step 2: Print checklist regardless (always useful)
cat << 'CHECKLIST'
REVIEW CHECKLIST:

[ ] Gotchas — for each STALE entry in gotchas.md:
    → ACTIVE:   Update "- Renewed: YYYY-MM-DD" to today
    → RESOLVED: Add "- Resolved: YYYY-MM-DD" and "- Resolution note: ..."
    → OBSOLETE: Change Status to RESOLVED, add note "obsolete — no longer applies"

[ ] Decisions — for each OVERDUE entry in decisions.md:
    → VALIDATED:  Write outcome, change Status, add "- Validated: YYYY-MM-DD"
    → REVERSED:   Write what went wrong, change Status (keep entry, never delete)
    → SUPERSEDED: Add "- Superseded by: [D-NNN]", change Status

[ ] Snapshots (run manually after editing):
    $ kb compact personal
    (writes monthly snapshot to personal/history/, trims current.md to ≤5 bullets)

[ ] Session review (optional, run manually):
    $ kb digest
    (scans recent sessions, proposes gotcha/decision updates)

CHECKLIST

# Step 3: Print file paths (open in editor if set)
echo "FILES TO EDIT:"
echo "  $VAULT_AI/personal/gotchas.md"
echo "  $VAULT_AI/personal/decisions.md"
echo ""

if [ -n "${EDITOR:-}" ]; then
  printf "Open in \$EDITOR (%s)? [y/N] " "$EDITOR"
  read -r answer
  if [ "$answer" = "y" ] || [ "$answer" = "Y" ]; then
    "$EDITOR" "$VAULT_AI/personal/gotchas.md" "$VAULT_AI/personal/decisions.md"
  fi
else
  echo "(\$EDITOR not set — open files manually)"
fi

echo ""
echo "Refresh complete. Log saved: $REFRESH_LOG"
```

---

## 6. JANITOR PATCH

### Add section `# 5b. KB HEALTH SCAN` to janitor.sh
### Insert between the existing archive-cleanup section and the health-report section.

```bash
# ============================================================================
# 5b. KB HEALTH SCAN
# ============================================================================
log "--- kb-health-scan ---"

GOTCHAS_FILE="$VAULT_AI/personal/gotchas.md"
DECISIONS_FILE="$VAULT_AI/personal/decisions.md"

# [Include shared functions: days_since, date_is_past, date_add_days,
#  parse_gotchas, parse_decisions, to_json_array]
# Copy function bodies here — do not source external file

KB_G_TOTAL=0; KB_G_ACTIVE=0; KB_G_WATCH=0; KB_G_RESOLVED=0
KB_G_STALE=0; KB_G_STALE_LIST=""
KB_D_TOTAL=0; KB_D_PENDING=0; KB_D_VALIDATED=0
KB_D_OVERDUE=0; KB_D_OVERDUE_LIST=""
KB_LAST_REFRESH="unknown"
KB_NEXT_REFRESH="unknown"

if [ -f "$GOTCHAS_FILE" ]; then
  while IFS='|' read -r gid status renewed title; do
    KB_G_TOTAL=$((KB_G_TOTAL + 1))
    case "$status" in
      ACTIVE)   KB_G_ACTIVE=$((KB_G_ACTIVE + 1)) ;;
      WATCH)    KB_G_WATCH=$((KB_G_WATCH + 1)) ;;
      RESOLVED) KB_G_RESOLVED=$((KB_G_RESOLVED + 1)) ;;
    esac
    if [ "$status" != "RESOLVED" ]; then
      age=$(days_since "$renewed")
      if [ "$age" -gt 30 ]; then
        KB_G_STALE=$((KB_G_STALE + 1))
        KB_G_STALE_LIST="$KB_G_STALE_LIST $gid"
      fi
    fi
  done < <(parse_gotchas "$GOTCHAS_FILE")
fi

if [ -f "$DECISIONS_FILE" ]; then
  while IFS='|' read -r did status validate_by title; do
    KB_D_TOTAL=$((KB_D_TOTAL + 1))
    case "$status" in
      PENDING)   KB_D_PENDING=$((KB_D_PENDING + 1)) ;;
      VALIDATED) KB_D_VALIDATED=$((KB_D_VALIDATED + 1)) ;;
    esac
    if [ "$status" = "PENDING" ] && [ "$validate_by" != "ONGOING" ]; then
      if date_is_past "$validate_by"; then
        KB_D_OVERDUE=$((KB_D_OVERDUE + 1))
        KB_D_OVERDUE_LIST="$KB_D_OVERDUE_LIST $did"
      fi
    fi
  done < <(parse_decisions "$DECISIONS_FILE")
fi

# Last refresh: most recent kb-refresh log on this host
HOSTNAME_SHORT=$(hostname -s)
LAST_LOG=$(ls "$LOG_DIR"/kb-refresh-*-${HOSTNAME_SHORT}.log 2>/dev/null | sort | tail -1)
if [ -n "$LAST_LOG" ]; then
  KB_LAST_REFRESH=$(basename "$LAST_LOG" .log | sed "s/kb-refresh-//" | sed "s/-${HOSTNAME_SHORT}//")
  KB_NEXT_REFRESH=$(date_add_days "$KB_LAST_REFRESH" 30)
fi

# Trim leading space from ID lists
KB_G_STALE_LIST="${KB_G_STALE_LIST# }"
KB_D_OVERDUE_LIST="${KB_D_OVERDUE_LIST# }"

log "kb-health: gotchas=$KB_G_TOTAL (stale=$KB_G_STALE) decisions=$KB_D_TOTAL (overdue=$KB_D_OVERDUE)"
```

### In the health JSON heredoc, add kb_health block.
Add BEFORE the final closing `}`. Also add a trailing comma to the last existing block (`"ai": {...},`).

```json
"kb_health": {
  "gotchas": {
    "total": $KB_G_TOTAL,
    "active": $KB_G_ACTIVE,
    "watch": $KB_G_WATCH,
    "resolved": $KB_G_RESOLVED,
    "stale_renewal": $KB_G_STALE,
    "stale_ids": $(to_json_array "$KB_G_STALE_LIST")
  },
  "decisions": {
    "total": $KB_D_TOTAL,
    "pending": $KB_D_PENDING,
    "validated": $KB_D_VALIDATED,
    "overdue_validation": $KB_D_OVERDUE,
    "overdue_ids": $(to_json_array "$KB_D_OVERDUE_LIST")
  },
  "last_refresh": "$KB_LAST_REFRESH",
  "next_refresh": "$KB_NEXT_REFRESH"
}
```

**Important:** `to_json_array` is called inline inside the heredoc using command substitution.
Heredoc variable expansion runs, but command substitution `$(...)` also runs inside heredoc.
This is standard bash heredoc behaviour — verify this works on both Mac and Linux during testing.

---

## 7. JANITOR PROTECTION (line count floor)

### Replace the existing append-only verification section with:

```bash
# ============================================================================
# 2. DELETION PROTECTION (line count floor — not strict append-only)
# ============================================================================
log "--- deletion-protection ---"

check_floor() {
  local file="$1"
  local label="$2"
  [ -f "$file" ] || { log "  missing: $label"; return; }

  CURRENT_LINES=$(wc -l < "$file")

  # Find most recent snapshot in history/
  HISTORY_DIR="$(dirname "$file")/history"
  BASENAME=$(basename "$file" .md)
  LATEST_SNAP=$(ls "$HISTORY_DIR/${BASENAME}-"*.md 2>/dev/null | sort | tail -1)

  if [ -z "$LATEST_SNAP" ]; then
    log "  no snapshot yet: $label ($CURRENT_LINES lines, floor not established)"
    return
  fi

  SNAP_LINES=$(wc -l < "$LATEST_SNAP")
  FLOOR=$(( SNAP_LINES * 80 / 100 ))  # 80% of last snapshot

  if [ "$CURRENT_LINES" -lt "$FLOOR" ]; then
    log "  ALERT: $label may have been bulk-deleted! current=$CURRENT_LINES, snapshot=$SNAP_LINES, floor=$FLOOR"
  else
    log "  ok: $label ($CURRENT_LINES lines, floor=$FLOOR)"
  fi
}

check_floor "$VAULT_AI/personal/gotchas.md"   "personal/gotchas.md"
check_floor "$VAULT_AI/personal/decisions.md" "personal/decisions.md"
```

---

## 8. MONTHLY CRON (both machines)

### Purpose: runs kb-review.sh non-interactively on 1st of month, logs result
### Log includes hostname so two machines don't conflict on Syncthing

```crontab
# KB monthly review — 1st of month, 09:00
0 9 1 * * VAULT_AI="$HOME/Vaults/Higgins/AI" bash "$HOME/dotfiles/scripts/kb-review.sh" > "$HOME/Vaults/Higgins/AI/_ops/janitor-logs/kb-review-$(date +\%Y-\%m-\%d)-$(hostname -s).log" 2>&1
```

**Add on both Mac and SuperBro** via `crontab -e`.

kb-refresh.sh is NOT in cron. Human runs it manually after seeing the review log or on a personal schedule.

---

## 9. COMMIT

Single commit to dotfiles after all files are implemented and tested:

```
feat(kb): monthly refresh workflow and evolution lifecycle

- Add kb-review.sh: staleness scanner (exit 1 when action needed)
- Add kb-refresh.sh: human-run monthly workflow with checklist
- Patch janitor.sh: add kb_health to nightly health JSON
- Patch janitor.sh: replace append-only check with line count floor
- Add docs/kb-evolution-plan-v2.md: format spec and implementation guide
```

---

## 10. TESTING CHECKLIST

Run every item. Do not mark complete until verified.

```
[ ] kb-review.sh exits 0 on clean vault (no stale entries)
[ ] kb-review.sh exits 1 when gotcha Renewed is >30 days ago
[ ] kb-review.sh exits 1 when decision is overdue (PENDING + past validate_by)
[ ] kb-review.sh skips ONGOING decisions correctly
[ ] kb-review.sh handles missing gotchas.md: prints warning, does not crash
[ ] kb-review.sh handles old-format entries (no [G-NNN]): skips them, does not crash
[ ] kb-review.sh prints correct "Next available ID" (max existing + 1)
[ ] kb-review.sh stale_ids output is correct (spot check manually)

[ ] kb-refresh.sh runs without error, prints full checklist
[ ] kb-refresh.sh does NOT hang waiting for input (except final editor prompt)
[ ] kb-refresh.sh writes log to correct path including hostname
[ ] kb-refresh.sh skips $EDITOR open when $EDITOR is unset

[ ] janitor.sh runs clean with kb_health section
[ ] janitor health JSON is valid: python3 -m json.tool health-$(date +%Y-%m-%d).json
[ ] stale_ids is a JSON array, not a string: grep '"stale_ids": \[' health-*.json
[ ] KB_NEXT_REFRESH is populated when a refresh log exists
[ ] KB_NEXT_REFRESH is "unknown" when no refresh log exists (first run)
[ ] Line count floor: check_floor prints "ok" on normal files
[ ] Line count floor: check_floor prints "ALERT" when test file is truncated >20%
[ ] Line count floor: check_floor prints "no snapshot yet" before first kb compact

[ ] All scripts run on macOS (days_since, date_add_days use -v flag)
[ ] All scripts run on Linux (days_since, date_add_days use -d flag)
[ ] Cron entry added on SuperBro: crontab -l | grep kb-review
```

---

## CRITICAL CONSTRAINTS (repeat for emphasis)

1. **Never auto-modify gotchas.md or decisions.md** — scripts are read-only
2. **kb-refresh.sh is human-only** — never add it to cron
3. **No git** — Syncthing is the only sync mechanism
4. **No external dependencies** — bash + awk + grep + sed + date only
5. **Cross-platform date math** — macOS uses `date -v`, Linux uses `date -d`
6. **Valid JSON always** — janitor health output must pass `python3 -m json.tool`
7. **Hostname in log filenames** — prevents Syncthing conflicts on log files
8. **command substitution in heredoc** — `$(to_json_array ...)` inside heredoc is valid bash, verify on both platforms
9. **Graceful degradation** — old-format entries (no [G-NNN]) are skipped silently, never crash

#!/bin/bash
# janitor.sh v3.1 — nightly vault maintenance with Big Pickle AI
# Supports manual run on any device, automated cron on SuperBro only
set -euo pipefail

VAULT_AI="${VAULT_AI:-$HOME/Vaults/Higgins/AI}"
VAULT_HIGGINS="${VAULT_HIGGINS:-$HOME/Vaults/Higgins}"
CONF_FILE="${CONF_FILE:-$HOME/dotfiles/scripts/janitor.conf}"
LOG_DIR="$VAULT_AI/_ops/janitor-logs"
REPORT_DIR="$LOG_DIR/reports"
DATE=$(date '+%Y-%m-%d')
LOG="$LOG_DIR/$DATE.log"

# Load config from dotfiles
JANITOR_AI_ENABLED=false
JANITOR_AI_KEY="${OPENCODE_API_KEY:-}"
JANITOR_AI_MODEL="big-pickle"
JANITOR_AI_TIMEOUT=10
JANITOR_SLIPPING_THRESHOLD=20
JANITOR_ARCHIVE_THRESHOLD=180
JANITOR_LOG_RETENTION=7

if [ -f "$CONF_FILE" ]; then
  source "$CONF_FILE"
fi

mkdir -p "$LOG_DIR" "$REPORT_DIR"

log() { echo "[$(date '+%H:%M:%S')] $*" | tee -a "$LOG"; }
err() { echo "[ERROR] $*" | tee -a "$LOG"; }

cd "$VAULT_AI"

# Detect OS for date/stat compatibility
if [[ "$OSTYPE" == "darwin"* ]]; then
  GET_MTIME() { stat -f%Sm -t%Y-%m-%d "$1" 2>/dev/null; }
else
  GET_MTIME() { stat -c%y "$1" 2>/dev/null | cut -d' ' -f1; }
fi
export -f GET_MTIME

log "=== Janitor v3.1 started ==="
log "Vault: $VAULT_AI"
log "AI: $JANITOR_AI_ENABLED | Model: $JANITOR_AI_MODEL"

# ============================================================================
# 0. DELETION PROTECTION (line count floor — wiki model, not append-only)
# ============================================================================
log "--- deletion-protection ---"

check_floor() {
  local file="$1"
  local label="$2"
  [ -f "$file" ] || { log "  missing: $label"; return; }

  # Abort on empty file — most dangerous sync truncation case
  if [ ! -s "$file" ]; then
    err "CRITICAL: $label is empty (possible sync truncation) — aborting"
    exit 1
  fi

  local current_lines
  current_lines=$(wc -l < "$file")

  # Find most recent snapshot in history/
  local history_dir
  history_dir="$(dirname "$file")/history"
  local basename_noext
  basename_noext=$(basename "$file" .md)
  local latest_snap
  latest_snap=$(ls "${history_dir}/${basename_noext}-"*.md 2>/dev/null | sort | tail -1 || true)

  if [ -z "$latest_snap" ]; then
    log "  no snapshot yet: $label ($current_lines lines, floor not established)"
    return
  fi

  local snap_lines floor
  snap_lines=$(wc -l < "$latest_snap")
  floor=$(( snap_lines * 80 / 100 ))

  if [ "$current_lines" -lt "$floor" ]; then
    log "  ALERT: $label may have been bulk-deleted! current=$current_lines, snapshot=$snap_lines, floor=$floor"
  else
    log "  ok: $label ($current_lines lines, floor=$floor)"
  fi
}

check_floor "personal/gotchas.md"   "personal/gotchas.md"
check_floor "personal/decisions.md" "personal/decisions.md"

# ============================================================================
# 1. RESOLVE SYNCTHING CONFLICTS + CLEANUP JUNK FILES
# ============================================================================
log "--- resolve-conflicts ---"

# Delete .DS_Store files (macOS metadata, no vault value)
DS_COUNT=$(find . -name '.DS_Store' -type f 2>/dev/null | wc -l | tr -d ' ')
if [ "$DS_COUNT" -gt 0 ]; then
  find . -name '.DS_Store' -type f -delete 2>/dev/null
  log "  deleted: $DS_COUNT .DS_Store files"
fi

RESOLVED=0
find . -name '.sync-conflict-*' -type f 2>/dev/null | while read conflict; do
  # Skip .DS_Store conflicts (not worth tracking)
  if [[ "$conflict" == *".DS_Store" ]]; then
    rm -f "$conflict"
    log "  skipped: .DS_Store conflict"
    continue
  fi
  
  ORIGINAL="${conflict%%.sync-conflict-*}"
  
  if [ ! -f "$ORIGINAL" ]; then
    mv "$conflict" "$ORIGINAL"
    log "  restored: $ORIGINAL"
  elif [ "$ORIGINAL" -nt "$conflict" ]; then
    rm "$conflict"
    log "  kept newer: $ORIGINAL"
  else
    mv "$ORIGINAL" "archive/$(basename "$ORIGINAL")-old-$(date +%s)"
    mv "$conflict" "$ORIGINAL"
    log "  replaced: $ORIGINAL (older version archived)"
  fi
  RESOLVED=$((RESOLVED + 1))
done
[ $RESOLVED -gt 0 ] && log "resolve-conflicts: $RESOLVED conflicts resolved" || log "resolve-conflicts: none found"

# ============================================================================
# 2. LOG ROTATION (7 days)
# ============================================================================
log "--- log-rotation ---"
CUTOFF=$(date -d "${JANITOR_LOG_RETENTION} days ago" +%Y-%m-%d 2>/dev/null || date -v-${JANITOR_LOG_RETENTION}d +%Y-%m-%d)
DELETED=0
for old_log in "$LOG_DIR"/*.log; do
  [ -f "$old_log" ] || continue
  LOG_DATE=$(basename "$old_log" .log)
  # Only compare if LOG_DATE has expected format YYYY-MM-DD
  if [[ "$LOG_DATE" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] && [[ "$LOG_DATE" < "$CUTOFF" ]]; then
    rm "$old_log"
    log "  deleted: $LOG_DATE (older than $CUTOFF)"
    DELETED=$((DELETED + 1))
  fi
done
log "log-rotation: deleted $DELETED old logs"

# ============================================================================
# 3. PROJECT ANALYSIS (mechanical preprocessing + optional AI)
# ============================================================================
log "--- project-analysis ---"
> "$REPORT_DIR/slipping-projects.md"
echo "# Slipping Projects Report — $DATE" >> "$REPORT_DIR/slipping-projects.md"
echo "" >> "$REPORT_DIR/slipping-projects.md"
echo "Mechanical preprocessing: categorize by staleness, AI only on 60+ day projects" >> "$REPORT_DIR/slipping-projects.md"
echo "" >> "$REPORT_DIR/slipping-projects.md"

# Mechanical pass 1: categorize by staleness
set +u  # Allow unbound arrays
declare -a ACTIVE REVIEW STALLED

for proj in projects/*/; do
  [ -d "$proj" ] || continue
  PROJ_NAME=$(basename "$proj")
  LAST_MOD=$(GET_MTIME "$proj")
  DAYS_OLD=$(( ($(date +%s) - $(date -j -f%Y-%m-%d "$LAST_MOD" +%s 2>/dev/null || date -d "$LAST_MOD" +%s 2>/dev/null || echo 0)) / 86400 ))
  
  if [ "$DAYS_OLD" -lt 20 ]; then
    ACTIVE+=("$PROJ_NAME|$LAST_MOD|$DAYS_OLD")
  elif [ "$DAYS_OLD" -lt 60 ]; then
    REVIEW+=("$PROJ_NAME|$LAST_MOD|$DAYS_OLD")
  else
    STALLED+=("$PROJ_NAME|$LAST_MOD|$DAYS_OLD")
  fi
done

log "mechanical-pass-1: ACTIVE=${#ACTIVE[@]} | REVIEW=${#REVIEW[@]} | STALLED=${#STALLED[@]}"

# Report table
echo "| Tier | Project | Last Modified | Days Old | Assessment |" >> "$REPORT_DIR/slipping-projects.md"
echo "|------|---------|---|---|---|" >> "$REPORT_DIR/slipping-projects.md"

# Active projects (0-20 days)
for entry in "${ACTIVE[@]}"; do
  IFS='|' read -r PROJ_NAME LAST_MOD DAYS_OLD <<< "$entry"
  echo "| Active | $PROJ_NAME | $LAST_MOD | $DAYS_OLD | Running (no action needed) |" >> "$REPORT_DIR/slipping-projects.md"
done

# Review projects (20-60 days)
for entry in "${REVIEW[@]}"; do
  IFS='|' read -r PROJ_NAME LAST_MOD DAYS_OLD <<< "$entry"
  log "  $PROJ_NAME: $DAYS_OLD days (review, no AI)"
  echo "| Review | $PROJ_NAME | $LAST_MOD | $DAYS_OLD | Check status (mechanical) |" >> "$REPORT_DIR/slipping-projects.md"
done

# Stalled projects (60+ days) — AI analysis if enabled
STALLED_COUNT=${#STALLED[@]}
if (( STALLED_COUNT > 0 )); then
  for entry in "${STALLED[@]}"; do
    IFS='|' read -r PROJ_NAME LAST_MOD DAYS_OLD <<< "$entry"
    
    if [ "$JANITOR_AI_ENABLED" = true ] && [ -n "$JANITOR_AI_KEY" ]; then
      # AI only on genuinely stalled projects
      CONTEXT=$(cat "projects/$PROJ_NAME/current.md" 2>/dev/null | head -3 | tr '\n' ' ' || echo "no content")
      RESPONSE=$(timeout $JANITOR_AI_TIMEOUT curl -s \
        "https://opencode.ai/zen/v1/responses" \
        -H "Authorization: Bearer $JANITOR_AI_KEY" \
        -H "Content-Type: application/json" \
        -d "{\"model\": \"$JANITOR_AI_MODEL\", \"messages\": [{\"role\": \"user\", \"content\": \"In one sentence: is this project slipping or reasonably paused? Last update: $LAST_MOD ($DAYS_OLD days ago). Project: $CONTEXT\"}]}" 2>/dev/null || echo "{}")
      
      AI_TEXT=$(echo "$RESPONSE" | jq -r '.choices[0].message.content // "API error"' 2>/dev/null || echo "Parse error")
      ASSESSMENT="$AI_TEXT"
      log "  $PROJ_NAME: $DAYS_OLD days (stalled, AI: $ASSESSMENT)"
    else
      ASSESSMENT="Stalled, needs investigation"
      log "  $PROJ_NAME: $DAYS_OLD days (stalled, mechanical)"
    fi
    
    echo "| Stalled | $PROJ_NAME | $LAST_MOD | $DAYS_OLD | $ASSESSMENT |" >> "$REPORT_DIR/slipping-projects.md"
  done
fi

echo "" >> "$REPORT_DIR/slipping-projects.md"
echo "**Summary:** ${#ACTIVE[@]} active | ${#REVIEW[@]} review | $STALLED_COUNT stalled" >> "$REPORT_DIR/slipping-projects.md"
log "project-analysis: ${#ACTIVE[@]} active | ${#REVIEW[@]} review | $STALLED_COUNT stalled"

# ============================================================================
# 4. ARCHIVE CLEANUP (180-day auto-consolidation)
# ============================================================================
log "--- archive-cleanup ---"
# Cross-platform date calculation for archive cutoff
if [[ "$OSTYPE" == "darwin"* ]]; then
  ARCHIVE_CUTOFF=$(date -v-${JANITOR_ARCHIVE_THRESHOLD}d +%Y-%m-%d)
else
  ARCHIVE_CUTOFF=$(date -d "${JANITOR_ARCHIVE_THRESHOLD} days ago" +%Y-%m-%d)
fi
ARCHIVE_MOVED=0
find archive -type f 2>/dev/null | while read file; do
  FILE_DATE=$(stat -f%Sm -t%Y-%m-%d "$file" 2>/dev/null || echo "unknown")
  if [[ "$FILE_DATE" < "$ARCHIVE_CUTOFF" ]]; then
    # Move to dated subdirectory in archive
    YEAR_MONTH=$(echo "$FILE_DATE" | cut -d- -f1-2)
    mkdir -p "archive/$YEAR_MONTH"
    mv "$file" "archive/$YEAR_MONTH/"
    log "  consolidated: $FILE_DATE → archive/$YEAR_MONTH/"
    ARCHIVE_MOVED=$((ARCHIVE_MOVED + 1))
  fi
done
log "archive-cleanup: consolidated $ARCHIVE_MOVED old files"

# ============================================================================
# 5. ME FOLDER NOTE (manual cleanup only)
# ============================================================================
log "--- me-folder ---"
log "  NOTE: Me/ is manual cleanup only (user-managed)"
log "  User should review and prune: inbox/, quick/, trash/ as needed"

# ============================================================================
# 5b. KB HEALTH SCAN
# ============================================================================
log "--- kb-health-scan ---"

# ── Shared utilities (copied — do not source external file) ──────────────────

_kb_days_since() {
  local d="$1" ts
  if [[ "$OSTYPE" == "darwin"* ]]; then
    ts=$(date -j -f%Y-%m-%d "$d" +%s 2>/dev/null) || { echo 9999; return; }
  else
    ts=$(date -d "$d" +%s 2>/dev/null) || { echo 9999; return; }
  fi
  echo $(( ($(date +%s) - ts) / 86400 ))
}

_kb_date_is_past() {
  local d="$1" ts today
  today=$(date +%s)
  if [[ "$OSTYPE" == "darwin"* ]]; then
    ts=$(date -j -f%Y-%m-%d "$d" +%s 2>/dev/null) || return 0
  else
    ts=$(date -d "$d" +%s 2>/dev/null) || return 0
  fi
  [ "$ts" -lt "$today" ]
}

_kb_date_add_days() {
  local d="$1" n="$2"
  if [[ "$OSTYPE" == "darwin"* ]]; then
    date -v+${n}d -j -f%Y-%m-%d "$d" +%Y-%m-%d 2>/dev/null || echo "unknown"
  else
    date -d "$d + $n days" +%Y-%m-%d 2>/dev/null || echo "unknown"
  fi
}

_kb_parse_gotchas() {
  local file="$1"
  awk '
    /^---/ { exit }
    BEGIN { id=""; title=""; status=""; renewed="" }
    /^## \[G-[0-9]+\]/ {
      if (id != "") print id "|" status "|" renewed "|" title
      match($0, /\[G-[0-9]+\]/)
      id      = substr($0, RSTART, RLENGTH)
      title   = substr($0, RSTART + RLENGTH + 1)
      status  = "UNKNOWN"
      renewed = "1970-01-01"
    }
    /^- Status: /  { status  = substr($0, 11) }
    /^- Renewed: / { renewed = substr($0, 12) }
    END { if (id != "") print id "|" status "|" renewed "|" title }
  ' "$file"
}

_kb_parse_decisions() {
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

# Converts space-separated IDs to JSON array: "G-001 G-003" → ["G-001","G-003"]
to_json_array() {
  local items="$1"
  [ -z "$items" ] && echo "[]" && return
  local json="[" first=true
  for item in $items; do
    [ "$first" = true ] && json="${json}\"${item}\"" || json="${json},\"${item}\""
    first=false
  done
  echo "${json}]"
}
export -f to_json_array

# ── Gotchas health ───────────────────────────────────────────────────────────

KB_G_TOTAL=0; KB_G_ACTIVE=0; KB_G_WATCH=0; KB_G_RESOLVED=0
KB_G_STALE=0; KB_G_STALE_LIST=""

if [ -f "personal/gotchas.md" ]; then
  while IFS='|' read -r gid status renewed title; do
    KB_G_TOTAL=$((KB_G_TOTAL + 1))
    case "$status" in
      ACTIVE)   KB_G_ACTIVE=$((KB_G_ACTIVE + 1)) ;;
      WATCH)    KB_G_WATCH=$((KB_G_WATCH + 1)) ;;
      RESOLVED) KB_G_RESOLVED=$((KB_G_RESOLVED + 1)) ;;
    esac
    if [ "$status" != "RESOLVED" ]; then
      age=$(_kb_days_since "$renewed")
      if [ "$age" -gt 30 ]; then
        KB_G_STALE=$((KB_G_STALE + 1))
        KB_G_STALE_LIST="$KB_G_STALE_LIST $gid"
      fi
    fi
  done < <(_kb_parse_gotchas "personal/gotchas.md")
fi

# ── Decisions health ─────────────────────────────────────────────────────────

KB_D_TOTAL=0; KB_D_PENDING=0; KB_D_VALIDATED=0
KB_D_OVERDUE=0; KB_D_OVERDUE_LIST=""

if [ -f "personal/decisions.md" ]; then
  while IFS='|' read -r did status validate_by title; do
    KB_D_TOTAL=$((KB_D_TOTAL + 1))
    case "$status" in
      PENDING)   KB_D_PENDING=$((KB_D_PENDING + 1)) ;;
      VALIDATED) KB_D_VALIDATED=$((KB_D_VALIDATED + 1)) ;;
    esac
    if [ "$status" = "PENDING" ] && [ "$validate_by" != "ONGOING" ]; then
      if _kb_date_is_past "$validate_by"; then
        KB_D_OVERDUE=$((KB_D_OVERDUE + 1))
        KB_D_OVERDUE_LIST="$KB_D_OVERDUE_LIST $did"
      fi
    fi
  done < <(_kb_parse_decisions "personal/decisions.md")
fi

# ── Last/next refresh dates ───────────────────────────────────────────────────

KB_LAST_REFRESH="unknown"
KB_NEXT_REFRESH="unknown"
HOSTNAME_SHORT=$(hostname -s)
LAST_LOG=$(ls "$LOG_DIR"/kb-refresh-*-${HOSTNAME_SHORT}.log 2>/dev/null | sort | tail -1 || true)
if [ -n "$LAST_LOG" ]; then
  KB_LAST_REFRESH=$(basename "$LAST_LOG" .log | sed "s/kb-refresh-//" | sed "s/-${HOSTNAME_SHORT}//")
  KB_NEXT_REFRESH=$(_kb_date_add_days "$KB_LAST_REFRESH" 30)
fi

# Trim leading space
KB_G_STALE_LIST="${KB_G_STALE_LIST# }"
KB_D_OVERDUE_LIST="${KB_D_OVERDUE_LIST# }"

log "kb-health: gotchas=$KB_G_TOTAL (stale=$KB_G_STALE) decisions=$KB_D_TOTAL (overdue=$KB_D_OVERDUE)"

# ============================================================================
# 6. HEALTH REPORT (JSON snapshot)
# ============================================================================
log "--- health-report ---"
PROJ_COUNT=$(find projects -maxdepth 1 -type d | wc -l)
PROJ_COUNT=$((PROJ_COUNT - 1))  # Subtract projects/ itself
ARCHIVE_COUNT=$(find archive -type f | wc -l)
ARCHIVE_SIZE=$(du -sh archive 2>/dev/null | cut -f1)
VAULT_SIZE=$(du -sh . 2>/dev/null | cut -f1)

cat > "$REPORT_DIR/health-$DATE.json" << HEALTH_EOF
{
  "date": "$DATE",
  "vault_size": "$VAULT_SIZE",
  "projects": {
    "total": $PROJ_COUNT,
    "active": ${#ACTIVE[@]},
    "review": ${#REVIEW[@]},
    "stalled": $STALLED_COUNT
  },
  "archive": {
    "files": $ARCHIVE_COUNT,
    "size": "$ARCHIVE_SIZE"
  },
  "logs": {
    "retained_days": $JANITOR_LOG_RETENTION,
    "cutoff_date": "$CUTOFF"
  },
  "ai": {
    "enabled": $JANITOR_AI_ENABLED,
    "model": "$JANITOR_AI_MODEL"
  },
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
}  
HEALTH_EOF
log "health-report: saved to $REPORT_DIR/health-$DATE.json"
set -u  # Re-enable unbound variable check

# ============================================================================
# DONE
# ============================================================================
log "=== Janitor complete ==="
log "Reports: $REPORT_DIR/"

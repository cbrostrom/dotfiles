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
# 0. APPEND-ONLY VERIFICATION
# ============================================================================
log "--- append-only-verification ---"
APPONLY_SAFE=true
for apponly_file in personal/decisions.md personal/gotchas.md; do
  if [ ! -f "$apponly_file" ]; then
    log "  warning: $apponly_file missing"
    continue
  fi
  if [ ! -s "$apponly_file" ]; then
    err "CRITICAL: $apponly_file empty (truncated by sync)"
    APPONLY_SAFE=false
    continue
  fi
  LINES=$(wc -l < "$apponly_file")
  log "  safe: $apponly_file ($LINES lines)"
done
[ "$APPONLY_SAFE" = false ] && err "Append-only files compromised, aborting" && exit 1

# ============================================================================
# 1. RESOLVE SYNCTHING CONFLICTS
# ============================================================================
log "--- resolve-conflicts ---"
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

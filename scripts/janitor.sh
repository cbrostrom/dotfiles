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
  if [[ "$LOG_DATE" < "$CUTOFF" ]]; then
    rm "$old_log"
    log "  deleted: $LOG_DATE (older than $CUTOFF)"
    DELETED=$((DELETED + 1))
  fi
done
log "log-rotation: deleted $DELETED old logs"

# ============================================================================
# 3. SLIPPING PROJECTS (20d threshold, with optional Big Pickle AI)
# ============================================================================
log "--- slipping-projects ---"
> "$REPORT_DIR/slipping-projects.md"
echo "# Slipping Projects Report — $DATE" >> "$REPORT_DIR/slipping-projects.md"
echo "" >> "$REPORT_DIR/slipping-projects.md"
echo "Threshold: $JANITOR_SLIPPING_THRESHOLD days | AI: $JANITOR_AI_ENABLED" >> "$REPORT_DIR/slipping-projects.md"
echo "" >> "$REPORT_DIR/slipping-projects.md"
echo "| Project | Last Modified | Days Old | Assessment |" >> "$REPORT_DIR/slipping-projects.md"
echo "|---------|---|---|---|" >> "$REPORT_DIR/slipping-projects.md"

SLIPPING_COUNT=0
for proj in projects/*/; do
  [ -d "$proj" ] || continue
  PROJ_NAME=$(basename "$proj")
  LAST_MOD=$(stat -f%Sm -t%Y-%m-%d "$proj" 2>/dev/null || echo "unknown")
  DAYS_OLD=$(( ($(date +%s) - $(date -j -f%Y-%m-%d "$LAST_MOD" +%s 2>/dev/null || echo 0)) / 86400 ))
  
  if [ "$DAYS_OLD" -ge "$JANITOR_SLIPPING_THRESHOLD" ]; then
    if [ "$JANITOR_AI_ENABLED" = true ] && [ -n "$JANITOR_AI_KEY" ]; then
      # Get AI assessment via Big Pickle
      CONTEXT=$(cat "$proj/current.md" 2>/dev/null | head -3 | tr '\n' ' ' || echo "no content")
      RESPONSE=$(timeout $JANITOR_AI_TIMEOUT curl -s \
        "https://opencode.ai/zen/v1/responses" \
        -H "Authorization: Bearer $JANITOR_AI_KEY" \
        -H "Content-Type: application/json" \
        -d "{\"model\": \"$JANITOR_AI_MODEL\", \"messages\": [{\"role\": \"user\", \"content\": \"In one sentence: is this project slipping or reasonably paused? Last update: $LAST_MOD ($DAYS_OLD days ago). Project: $CONTEXT\"}]}" 2>/dev/null || echo "{}")
      
      AI_TEXT=$(echo "$RESPONSE" | jq -r '.choices[0].message.content // "API error"' 2>/dev/null || echo "Parse error")
      ASSESSMENT="$AI_TEXT"
      log "  $PROJ_NAME: $DAYS_OLD days (AI: $ASSESSMENT)"
    else
      ASSESSMENT="Needs review (mechanical: $DAYS_OLD days idle)"
      log "  $PROJ_NAME: $DAYS_OLD days (mechanical)"
    fi
    
    echo "| $PROJ_NAME | $LAST_MOD | $DAYS_OLD | $ASSESSMENT |" >> "$REPORT_DIR/slipping-projects.md"
    SLIPPING_COUNT=$((SLIPPING_COUNT + 1))
  fi
done

echo "" >> "$REPORT_DIR/slipping-projects.md"
echo "**Summary:** $SLIPPING_COUNT projects flagged" >> "$REPORT_DIR/slipping-projects.md"
log "slipping-projects: $SLIPPING_COUNT projects need review"

# ============================================================================
# 4. ARCHIVE CLEANUP (180-day auto-consolidation)
# ============================================================================
log "--- archive-cleanup ---"
ARCHIVE_CUTOFF=$(date -d "${JANITOR_ARCHIVE_THRESHOLD} days ago" +%Y-%m-%d 2>/dev/null || date -v-${JANITOR_ARCHIVE_THRESHOLD}d +%Y-%m-%d)
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
    "slipping": $SLIPPING_COUNT
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

# ============================================================================
# DONE
# ============================================================================
log "=== Janitor complete ==="
log "Reports: $REPORT_DIR/"

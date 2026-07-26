#!/usr/bin/env bash
# janitor.sh — nightly vault maintenance
# Runs: resolve-conflicts → lint → prune → compact → session-promote → mem-route
# Designed for cron or manual run. Syncthing handles sync; no git dependency.
set -euo pipefail

VAULT_AI="${VAULT_AI:-$HOME/Vaults/Higgins/AI}"
KB="$VAULT_AI/tools/kb"
LOG_DIR="$VAULT_AI/_ops/janitor-logs"
DATE=$(date '+%Y-%m-%d')
LOG="$LOG_DIR/$DATE.log"

mkdir -p "$LOG_DIR"

log() { echo "[$(date '+%H:%M:%S')] $*" | tee -a "$LOG"; }

cd "$VAULT_AI"
log "=== Janitor started ==="
log "Vault: $VAULT_AI"

# 0. Resolve Syncthing conflicts
log "--- resolve-conflicts ---"
CONFLICT_COUNT=0
RESOLVED_COUNT=0
CONFLICT_DIR="$VAULT_AI/_ops/sync-conflicts"
mkdir -p "$CONFLICT_DIR"

while IFS= read -r -r conflict; do
  CONFLICT_COUNT=$((CONFLICT_COUNT + 1))
  CONFLICT_BASENAME=$(basename "$conflict")

  # Skip .DS_Store conflicts — not worth tracking
  if [[ "$CONFLICT_BASENAME" == *".DS_Store" ]]; then
    rm "$conflict"
    log "  conflict (ds-store): deleted $CONFLICT_BASENAME"
    RESOLVED_COUNT=$((RESOLVED_COUNT + 1))
    continue
  fi

  ORIGINAL="${conflict%%.sync-conflict-*}"

  # If resolved path is a directory (conflict at vault root), skip
  if [ -d "$ORIGINAL" ]; then
    mv "$conflict" "$CONFLICT_DIR/$CONFLICT_BASENAME"
    log "  conflict (root orphan): archived $CONFLICT_BASENAME"
    RESOLVED_COUNT=$((RESOLVED_COUNT + 1))
    continue
  fi

  if [ ! -f "$ORIGINAL" ]; then
    mv "$conflict" "$ORIGINAL"
    log "  conflict (orphan): restored $(basename "$ORIGINAL")"
    RESOLVED_COUNT=$((RESOLVED_COUNT + 1))
    continue
  fi

  if [ "$ORIGINAL" -nt "$conflict" ]; then
    mv "$conflict" "$CONFLICT_DIR/$CONFLICT_BASENAME"
    log "  conflict: kept original, archived $CONFLICT_BASENAME"
  else
    mv "$ORIGINAL" "$CONFLICT_DIR/$(basename "$ORIGINAL")"
    mv "$conflict" "$ORIGINAL"
    log "  conflict: replaced with newer, archived $(basename "$ORIGINAL")"
  fi
  RESOLVED_COUNT=$((RESOLVED_COUNT + 1))
done < <(find "$VAULT_AI" -name '.sync-conflict-*' -type f 2>/dev/null)

log "resolve-conflicts: $RESOLVED_COUNT resolved of $CONFLICT_COUNT found"

# 1. Lint
log "--- kb lint ---"
if "$KB" lint >> "$LOG" 2>&1; then
  log "lint: OK"
else
  log "lint: ERRORS (check log)"
fi

# 2. Prune
log "--- kb prune ---"
if "$KB" prune >> "$LOG" 2>&1; then
  log "prune: OK"
else
  log "prune: ERRORS (check log)"
fi

# 3. Compact
log "--- kb compact ---"
if "$KB" compact >> "$LOG" 2>&1; then
  log "compact: OK"
else
  log "compact: ERRORS (check log)"
fi

# 4. Session promote (gotcha scanner)
log "--- session-promote ---"
if [ -x "$VAULT_AI/tools/session-promote" ]; then
  if "$VAULT_AI/tools/session-promote" >> "$LOG" 2>&1; then
    log "session-promote: OK"
  else
    log "session-promote: ERRORS (check log)"
  fi
else
  log "session-promote: skipped (not found or not executable)"
fi

# 5. Mem routing (classify scraps → route to projects or personal)
log "--- mem routing ---"
MEM_DIR="$VAULT_AI/_ops/mem"
MEM_PROCESSED="$MEM_DIR/processed"
if [ -d "$MEM_DIR" ]; then
  mkdir -p "$MEM_PROCESSED"
  SCRAP_COUNT=0
  ROUTED_COUNT=0
  
  for file in "$MEM_DIR"/scraps-*.md; do
    [ -f "$file" ] || continue
    SCRAP_COUNT=$((SCRAP_COUNT + 1))
    BASENAME=$(basename "$file")
    
    # Parse entries (separated by ---)
    while IFS= read -r -d '' entry || [ -n "$entry" ]; do
      # Extract Note field
      NOTE=$(echo "$entry" | grep -A1 "^Note:" | tail -1 | sed 's/^ *//')
      REPO=$(echo "$entry" | grep -A1 "^Repo:" | tail -1 | sed 's/^ *//')
      
      [ -z "$NOTE" ] && continue
      
      # Simple keyword classification
      PROJECT=""
      if echo "$NOTE" | grep -qiE '(shopify|liquid|theme|akqa)'; then
        PROJECT="akqa-denmark-shopify-theme-build"
      elif echo "$NOTE" | grep -qiE '(tauri|huskr|todo)'; then
        PROJECT="huskr"
      elif echo "$NOTE" | grep -qiE '(hopper|browser|sidebar)'; then
        PROJECT="hopper"
      elif echo "$NOTE" | grep -qiE '(laesr|rss|feed)'; then
        PROJECT="laesr"
      elif echo "$NOTE" | grep -qiE '(dotfiles|shell|zsh|hook)'; then
        PROJECT="dotfiles"
      elif echo "$NOTE" | grep -qiE '(pi|deck|ui)'; then
        PROJECT="pi-deck"
      fi
      
      # Route to project or personal
      if [ -n "$PROJECT" ] && [ -d "$VAULT_AI/projects/$PROJECT" ]; then
        echo "- $NOTE [mem: $BASENAME]" >> "$VAULT_AI/projects/$PROJECT/current.md"
        log "  routed → projects/$PROJECT: $NOTE"
      else
        echo "- $NOTE [mem: $BASENAME]" >> "$VAULT_AI/personal/current.md"
        log "  routed → personal: $NOTE"
      fi
      ROUTED_COUNT=$((ROUTED_COUNT + 1))
    done < <(awk '/^---$/{if(entry) print entry; entry=""} /^/{entry=entry $0 "\n"} END{if(entry) print entry}' "$file")
    
    # Move processed file
    mv "$file" "$MEM_PROCESSED/$BASENAME"
  done
  
  log "mem: processed $SCRAP_COUNT file(s), routed $ROUTED_COUNT entries"
else
  log "mem: skipped (no _ops/mem/ directory)"
fi

log "=== Janitor done ==="

#!/usr/bin/env bash
# janitor.sh — nightly vault maintenance
# Runs: lint → prune → compact → session-promote → git commit + push
# Designed for cron on SuperBro (central hub) or any machine.
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

# 5. Git commit + push
log "--- git ---"
CHANGES=$(git status --porcelain)
if [ -n "$CHANGES" ]; then
  git add -A
  git commit -m "janitor: nightly maintenance $DATE" >> "$LOG" 2>&1
  git push >> "$LOG" 2>&1
  log "git: committed + pushed"
else
  log "git: nothing to commit"
fi

log "=== Janitor done ==="

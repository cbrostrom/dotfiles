#!/usr/bin/env bash
# vault-inventory.sh — structured vault audit
# Outputs compact markdown summary (~3KB). No mutations.
set -euo pipefail

VAULT_AI="${VAULT_AI:-$HOME/Vaults/Higgins/AI}"
TODAY=$(date +%Y-%m-%d)

# Cross-platform date utils
if [[ "$OSTYPE" == "darwin"* ]]; then
  days_since() {
    local ts
    ts=$(date -j -f%Y-%m-%d "$1" +%s 2>/dev/null) || { echo 9999; return; }
    echo $(( ($(date +%s) - ts) / 86400 ))
  }
  mtime_date() { stat -f%Sm -t%Y-%m-%d "$1" 2>/dev/null || echo "unknown"; }
else
  days_since() {
    local ts
    ts=$(date -d "$1" +%s 2>/dev/null) || { echo 9999; return; }
    echo $(( ($(date +%s) - ts) / 86400 ))
  }
  mtime_date() { stat -c%y "$1" 2>/dev/null | cut -d' ' -f1 || echo "unknown"; }
fi

hr() { echo ""; echo "---"; echo ""; }

echo "# Vault Inventory — $TODAY"
echo "> Root: $VAULT_AI"
echo ""

# ── VAULT SIZE ────────────────────────────────────────────────
echo "## Size Overview"
echo ""
du -sh "$VAULT_AI" 2>/dev/null | awk '{print "**Total:** " $1}'
echo ""
echo "| Tier | Size |"
echo "|------|------|"
for dir in personal projects modules tools infra sessions archive _ops; do
  path="$VAULT_AI/$dir"
  if [ -d "$path" ]; then
    size=$(du -sh "$path" 2>/dev/null | cut -f1)
    echo "| $dir/ | $size |"
  fi
done

hr

# ── PERSONAL ──────────────────────────────────────────────────
echo "## personal/"
echo ""
echo "| File | Size | Modified |"
echo "|------|------|----------|"
for f in "$VAULT_AI/personal/"*.md; do
  [ -f "$f" ] || continue
  name=$(basename "$f")
  size=$(du -sh "$f" 2>/dev/null | cut -f1)
  mod=$(mtime_date "$f")
  echo "| $name | $size | $mod |"
done
# History snapshots
HIST_COUNT=$(ls "$VAULT_AI/personal/history/" 2>/dev/null | wc -l | tr -d ' ')
HIST_SIZE=$(du -sh "$VAULT_AI/personal/history/" 2>/dev/null | cut -f1)
echo ""
echo "history/: $HIST_COUNT snapshots, $HIST_SIZE total"

hr

# ── PROJECTS ──────────────────────────────────────────────────
echo "## projects/"
echo ""
ACTIVE=(); REVIEW=(); STALE=()
set +u

for proj in "$VAULT_AI/projects/"/*/; do
  [ -d "$proj" ] || continue
  name=$(basename "$proj")
  mod=$(mtime_date "$proj")
  age=$(days_since "$mod")
  entry="$name|$mod|${age}d"
  if   [ "$age" -lt 20 ];  then ACTIVE+=("$entry")
  elif [ "$age" -lt 60 ];  then REVIEW+=("$entry")
  else                          STALE+=("$entry")
  fi
done

echo "**Active (<20d):** ${#ACTIVE[@]}"
for e in "${ACTIVE[@]}"; do IFS='|' read -r n m a <<< "$e"; echo "  - $n ($a, $m)"; done
echo ""
echo "**Review (20-60d):** ${#REVIEW[@]}"
for e in "${REVIEW[@]}"; do IFS='|' read -r n m a <<< "$e"; echo "  - $n ($a, $m)"; done
echo ""
echo "**Stale (60d+):** ${#STALE[@]}"
for e in "${STALE[@]}"; do IFS='|' read -r n m a <<< "$e"; echo "  - $n ($a, $m)"; done

hr

# ── MODULES ───────────────────────────────────────────────────
echo "## modules/"
echo ""
if [ -d "$VAULT_AI/modules" ]; then
  MOD_COUNT=$(find "$VAULT_AI/modules" -maxdepth 1 -mindepth 1 -type d | wc -l | tr -d ' ')
  MOD_SIZE=$(du -sh "$VAULT_AI/modules" 2>/dev/null | cut -f1)
  echo "$MOD_COUNT modules, $MOD_SIZE total"
  echo ""
  echo "| Module | Size | Modified |"
  echo "|--------|------|----------|"
  for d in "$VAULT_AI/modules/"/*/; do
    [ -d "$d" ] || continue
    name=$(basename "$d")
    size=$(du -sh "$d" 2>/dev/null | cut -f1)
    mod=$(mtime_date "$d")
    age=$(days_since "$mod")
    flag=""
    [ "$age" -gt 60 ] && flag=" ⚠ stale"
    echo "| $name | $size | $mod$flag |"
  done
else
  echo "Not found."
fi

hr

# ── TOOLS ─────────────────────────────────────────────────────
echo "## tools/"
echo ""
if [ -d "$VAULT_AI/tools" ]; then
  echo "| Item | Type | Size | Modified |"
  echo "|------|------|------|----------|"
  for item in "$VAULT_AI/tools/"*/; do
    [ -e "$item" ] || continue
    name=$(basename "$item")
    type="dir"
    [ -f "$item" ] && type="file"
    size=$(du -sh "$item" 2>/dev/null | cut -f1)
    mod=$(mtime_date "$item")
    echo "| $name | $type | $size | $mod |"
  done
else
  echo "Not found."
fi

hr

# ── SESSIONS ──────────────────────────────────────────────────
echo "## sessions/"
echo ""
if [ -d "$VAULT_AI/sessions" ]; then
  SESS_TOTAL=$(find "$VAULT_AI/sessions" -name "*.md" | wc -l | tr -d ' ')
  SESS_SIZE=$(du -sh "$VAULT_AI/sessions" 2>/dev/null | cut -f1)
  echo "$SESS_TOTAL session files, $SESS_SIZE total"
  echo ""
  # Per-month breakdown (2026 only for now)
  echo "| Month | Count | Size |"
  echo "|-------|-------|------|"
  for month_dir in "$VAULT_AI/sessions/2026/"/*/; do
    [ -d "$month_dir" ] || continue
    month=$(basename "$month_dir")
    count=$(find "$month_dir" -name "*.md" | wc -l | tr -d ' ')
    size=$(du -sh "$month_dir" 2>/dev/null | cut -f1)
    echo "| 2026-$month | $count | $size |"
  done
else
  echo "Not found."
fi

hr

# ── ARCHIVE ───────────────────────────────────────────────────
echo "## archive/"
echo ""
if [ -d "$VAULT_AI/archive" ]; then
  ARC_FILES=$(find "$VAULT_AI/archive" -name "*.md" | wc -l | tr -d ' ')
  ARC_SIZE=$(du -sh "$VAULT_AI/archive" 2>/dev/null | cut -f1)
  echo "$ARC_FILES files, $ARC_SIZE total"
  echo ""
  echo "| File | Size | Modified |"
  echo "|------|------|----------|"
  for f in "$VAULT_AI/archive/"*.md; do
    [ -f "$f" ] || continue
    name=$(basename "$f")
    size=$(du -sh "$f" 2>/dev/null | cut -f1)
    mod=$(mtime_date "$f")
    echo "| $name | $size | $mod |"
  done
else
  echo "Not found."
fi

hr

# ── ANOMALIES ─────────────────────────────────────────────────
echo "## Anomalies"
echo ""

ANOMALY_COUNT=0

# Sync conflicts
CONFLICTS=$(find "$VAULT_AI" -name "*.sync-conflict-*" 2>/dev/null)
if [ -n "$CONFLICTS" ]; then
  echo "**⚠ Sync conflicts:**"
  echo "$CONFLICTS" | while read -r f; do echo "  - $(basename "$f")"; done
  ANOMALY_COUNT=$((ANOMALY_COUNT + 1))
  echo ""
fi

# Large files (>500KB individually)
LARGE=$(find "$VAULT_AI" -name "*.md" -size +500k 2>/dev/null | grep -v "sessions/\|history/" || true)
if [ -n "$LARGE" ]; then
  echo "**⚠ Large files (>500KB, excl. sessions/history):**"
  echo "$LARGE" | while read -r f; do
    size=$(du -sh "$f" 2>/dev/null | cut -f1)
    echo "  - $(realpath --relative-to="$VAULT_AI" "$f" 2>/dev/null || basename "$f") ($size)"
  done
  ANOMALY_COUNT=$((ANOMALY_COUNT + 1))
  echo ""
fi

# Flat .md files at vault root (only AGENTS.md README.md PLAN.md allowed)
FLAT=$(find "$VAULT_AI" -maxdepth 1 -name "*.md" | grep -vE "AGENTS\.md|README\.md|PLAN\.md" || true)
if [ -n "$FLAT" ]; then
  echo "**⚠ Unexpected flat .md at vault root:**"
  echo "$FLAT" | while read -r f; do echo "  - $(basename "$f")"; done
  ANOMALY_COUNT=$((ANOMALY_COUNT + 1))
  echo ""
fi

# Empty project folders
EMPTY_PROJ=$(find "$VAULT_AI/projects" -maxdepth 1 -mindepth 1 -type d -empty 2>/dev/null || true)
if [ -n "$EMPTY_PROJ" ]; then
  echo "**⚠ Empty project folders:**"
  echo "$EMPTY_PROJ" | while read -r d; do echo "  - $(basename "$d")"; done
  ANOMALY_COUNT=$((ANOMALY_COUNT + 1))
  echo ""
fi

# Non-.md files outside _ops/tools/assets
NONMD=$(find "$VAULT_AI/personal" "$VAULT_AI/projects" "$VAULT_AI/modules" \
  -name "*.html" -o -name "*.json" -o -name "*.yaml" -o -name "*.log" 2>/dev/null | head -10 || true)
if [ -n "$NONMD" ]; then
  echo "**⚠ Non-markdown files in content tiers:**"
  echo "$NONMD" | while read -r f; do echo "  - $(realpath --relative-to="$VAULT_AI" "$f" 2>/dev/null || basename "$f")"; done
  ANOMALY_COUNT=$((ANOMALY_COUNT + 1))
  echo ""
fi

[ "$ANOMALY_COUNT" -eq 0 ] && echo "None found." || echo "**Total anomaly categories: $ANOMALY_COUNT**"

hr

echo "## Summary"
echo ""
echo "| Metric | Value |"
echo "|--------|-------|"
echo "| Scan date | $TODAY |"
echo "| Projects active | ${#ACTIVE[@]} |"
echo "| Projects review | ${#REVIEW[@]} |"
echo "| Projects stale | ${#STALE[@]} |"
echo "| Anomaly categories | $ANOMALY_COUNT |"

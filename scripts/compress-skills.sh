#!/usr/bin/env bash
# compress-skills.sh — caveman-compress SKILL.md files in plugin cache
# Usage:
#   compress-skills.sh              # compress all installed CC skills
#   compress-skills.sh <name>       # compress skills matching name (substring)
#   compress-skills.sh --list       # list skills with sizes, no compress
#   compress-skills.sh --status     # show which are compressed vs not
#
# Skills in plugin cache get overwritten on plugin update.
# Re-run this script after `claude plugin update` to re-compress.

set -euo pipefail

PLUGIN_DIR="${HOME}/.claude/plugins/cache"
COMPRESS_SCRIPT_PATTERN="compress/scripts"
CAVEMAN_CACHE="${HOME}/.claude/plugins/cache/caveman"

# Find the caveman compress python module
find_compress_dir() {
  rtk proxy find "$CAVEMAN_CACHE" -type d -name "compress" 2>/dev/null | head -1
}

run_compress() {
  local skill_md="$1"
  local compress_dir
  compress_dir=$(find_compress_dir)
  if [[ -z "$compress_dir" ]]; then
    echo "ERROR: caveman compress module not found" >&2
    return 1
  fi
  (cd "$compress_dir" && python3 -m scripts "$skill_md" 2>&1)
}

# Find all SKILL.md files (CC-specific: under .claude/skills/ path)
find_skills() {
  rtk proxy find "$PLUGIN_DIR" -path "*/skills/*/SKILL.md" -not -name "*.original.md" 2>/dev/null
}

# Deduplicate: for same skill-name across versions, keep newest file (by mtime)
# Uses awk to avoid bash 3.x associative array limitation
dedup_skills() {
  # Sort by skill-name then mtime descending, pick first per skill-name
  while IFS= read -r path; do
    skill_name=$(basename "$(dirname "$path")")
    mtime=$(stat -f "%m" "$path" 2>/dev/null || stat -c "%Y" "$path" 2>/dev/null)
    echo "$mtime $skill_name $path"
  done | sort -k2,2 -k1,1rn | awk '!seen[$2]++ {print $3}'
}

list_skills() {
  local filter="${1:-}"
  while IFS= read -r path; do
    [[ -n "$filter" && "$path" != *"$filter"* ]] && continue
    skill_name=$(basename "$(dirname "$path")")
    size=$(wc -c < "$path")
    tokens_est=$(( size / 4 ))
    original="${path%.md}.original.md"
    if [[ -f "$original" ]]; then
      orig_size=$(wc -c < "$original")
      saved=$(( orig_size - size ))
      echo "COMPRESSED  ${skill_name}  ${size}B (~${tokens_est}tok)  saved ${saved}B  ${path}"
    else
      echo "PLAIN       ${skill_name}  ${size}B (~${tokens_est}tok)  ${path}"
    fi
  done < <(find_skills | dedup_skills | sort)
}

compress_skills() {
  local filter="${1:-}"
  local total_before=0
  local total_after=0
  local count=0
  local skipped=0

  while IFS= read -r path; do
    [[ -n "$filter" && "$path" != *"$filter"* ]] && continue
    skill_name=$(basename "$(dirname "$path")")
    size_before=$(wc -c < "$path")
    original="${path%.md}.original.md"

    if [[ -f "$original" ]]; then
      echo "SKIP  $skill_name (already compressed, backup exists)"
      (( skipped++ )) || true
      continue
    fi

    echo -n "COMPRESSING  $skill_name (${size_before}B)... "
    set +e
    output=$(run_compress "$path" 2>&1)
    exit_code=$?
    set -e

    if [[ $exit_code -eq 0 ]]; then
      size_after=$(wc -c < "$path")
      saved=$(( size_before - size_after ))
      pct=$(( saved * 100 / size_before ))
      echo "done  -${saved}B (-${pct}%)"
      total_before=$(( total_before + size_before ))
      total_after=$(( total_after + size_after ))
      (( count++ )) || true
    else
      echo "FAILED"
      echo "$output" | grep -E "^(ERROR|❌|⚠️)" | head -3 || true
    fi
  done < <(find_skills | dedup_skills | sort)

  if [[ $count -gt 0 ]]; then
    total_saved=$(( total_before - total_after ))
    total_pct=$(( total_saved * 100 / total_before ))
    echo ""
    echo "Compressed: $count skills  Total saved: ${total_saved}B (~$(( total_saved / 4 )) tokens, -${total_pct}%)"
    echo "Skipped: $skipped (already compressed)"
  else
    echo "Nothing compressed. Skipped: $skipped"
  fi
}

# Force re-compress (remove backup first, then compress)
recompress_skills() {
  local filter="${1:-}"
  while IFS= read -r path; do
    [[ -n "$filter" && "$path" != *"$filter"* ]] && continue
    original="${path%.md}.original.md"
    if [[ -f "$original" ]]; then
      skill_name=$(basename "$(dirname "$path")")
      echo "RESET  $skill_name (removing backup for re-compress)"
      # Restore original first, then re-compress
      cp "$original" "$path"
      rm "$original"
    fi
  done < <(find_skills | dedup_skills | sort)
  compress_skills "$filter"
}

case "${1:-}" in
  --list|-l)
    list_skills "${2:-}"
    ;;
  --status|-s)
    echo "=== Skill compression status ==="
    list_skills "${2:-}"
    ;;
  --recompress|-r)
    echo "=== Re-compressing (restoring originals first) ==="
    recompress_skills "${2:-}"
    ;;
  --help|-h)
    sed -n '2,8p' "$0" | sed 's/^# //'
    ;;
  *)
    compress_skills "${1:-}"
    ;;
esac

#!/usr/bin/env bash
# brain-pick.sh — interactive project starter
# Lists active projects from vault; shows Next Steps + Open Decisions on select.
# Writes selected slug to ~/.claude/.active-project (read by brain-load.sh fallback).
#
# Usage:
#   brain-pick              # interactive picker
#   brain-pick --preview <file>   # internal: fzf preview helper

set -euo pipefail

# Platform detection
if grep -qi microsoft /proc/version 2>/dev/null || [[ -n "${WSL_DISTRO_NAME:-}" ]]; then
  VAULT="/mnt/c/Users/christian/Obsidian/Brain"
elif [[ "$(uname)" == "Darwin" ]]; then
  VAULT="$HOME/Vaults/Brain"
else
  VAULT="$HOME/Vaults/Brain"
fi

ACTIVE_FILE="$HOME/.claude/.active-project"
SCRIPT_PATH="$(realpath "$0")"

# --preview mode (internal, called by fzf)
if [[ "${1:-}" == "--preview" ]]; then
  f="$2"
  slug=$(basename "$f" .md)
  echo "━━━ $slug ━━━"
  echo ""
  awk '
    /^## (Next Steps|Open Decisions|Current State)/ { p=1; print; next }
    p && /^## / { p=0 }
    p { print }
  ' "$f" | head -50
  echo ""
  if [[ "$(uname)" == "Darwin" ]]; then
    echo "last updated: $(stat -f "%Sm" -t "%Y-%m-%d %H:%M" "$f" 2>/dev/null || echo "unknown")"
  else
    echo "last updated: $(stat -c "%y" "$f" 2>/dev/null | cut -d'.' -f1 || echo "unknown")"
  fi
  exit 0
fi

# Collect candidate files from Brains/ + Plans/Active/
find_projects() {
  local brains_dir="$VAULT/Brains"
  local plans_dir="$VAULT/Plans/Active"
  [[ -d "$brains_dir" ]] && find "$brains_dir" -maxdepth 1 -name "*.md" ! -name "_*" ! -name "Brain.md" 2>/dev/null
  [[ -d "$plans_dir"  ]] && find "$plans_dir"  -maxdepth 1 -name "*.md" ! -name "_*" 2>/dev/null
}

# Keep only files with status: active in frontmatter (Plans/Active/ pass through)
filter_active() {
  while IFS= read -r f; do
    if [[ "$f" == */Plans/Active/* ]]; then
      echo "$f"
    elif grep -q "^status: active" "$f" 2>/dev/null; then
      echo "$f"
    fi
  done
}

# Format for fzf display: "TYPE  slug  /path/to/file"
format_entry() {
  while IFS= read -r f; do
    if [[ "$f" == */Brains/* ]]; then
      tag="brain"
    else
      tag="plan "
    fi
    slug=$(basename "$f" .md)
    echo "$tag  $slug  $f"
  done
}

# Show brief summary (used after selection)
print_brief() {
  local f="$1"
  local slug
  slug=$(basename "$f" .md)
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  printf "  Starting: %s\n" "$slug"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  awk '
    /^## (Next Steps|Open Decisions|Current State)/ { p=1; print; next }
    p && /^## / { p=0 }
    p { print }
  ' "$f" | head -40
  echo ""
}

# Build candidate list
mapfile -t all_files < <(find_projects | filter_active | sort)

if [[ ${#all_files[@]} -eq 0 ]]; then
  echo "No active projects found in $VAULT" >&2
  exit 1
fi

# Pick
if command -v fzf >/dev/null 2>&1; then
  selected=$(printf '%s\n' "${all_files[@]}" | format_entry | \
    fzf --ansi \
        --with-nth=1,2 \
        --delimiter='  ' \
        --preview="\"$SCRIPT_PATH\" --preview {3}" \
        --preview-window=right:55%:wrap \
        --prompt="▶ project: " \
        --header="Enter=start  Esc=cancel" \
        --height=80% \
        --border=rounded
  ) || { echo "cancelled"; exit 0; }
  [ -z "$selected" ] && echo "cancelled" && exit 0
  selected_file=$(echo "$selected" | awk -F'  ' '{print $3}')
else
  # Fallback: numbered list
  echo "=== Active Projects ==="
  for i in "${!all_files[@]}"; do
    slug=$(basename "${all_files[$i]}" .md)
    tag="brain"
    [[ "${all_files[$i]}" == */Plans/Active/* ]] && tag="plan "
    printf "  %2d.  %s  %s\n" "$((i+1))" "$tag" "$slug"
  done
  echo ""
  read -rp "Select [1-${#all_files[@]}]: " choice
  [[ -z "$choice" ]] && echo "cancelled" && exit 0
  selected_file="${all_files[$((choice-1))]}"
fi

slug=$(basename "$selected_file" .md)

# Write active project hint
echo "$slug" > "$ACTIVE_FILE"

# Print standup brief
print_brief "$selected_file"
echo "Active project → $ACTIVE_FILE ($slug)"

#!/usr/bin/env zsh
# defender-exclusions.sh
# Applies Microsoft Defender exclusions defined in macos/defender-exclusions.conf
# via the official mdatp CLI — the same API the Defender GUI calls.
#
# Managed (MDM/Intune/JAMF-locked) settings are silently skipped by mdatp.
# Safe to re-run: already-excluded paths are detected and skipped.
#
# Usage:
#   ./defender-exclusions.sh           # apply all exclusions from conf
#   ./defender-exclusions.sh --dry-run # preview without making changes

set -euo pipefail

GREP=/usr/bin/grep
SED=/usr/bin/sed
SCRIPT_DIR="${0:A:h}"
CONF="$SCRIPT_DIR/macos/defender-exclusions.conf"

DRY_RUN=false
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=true

# ── Preflight ─────────────────────────────────────────────────────────────────

MDATP=$(command -v mdatp 2>/dev/null || true)
if [[ -z "$MDATP" ]]; then
  echo "error: mdatp not found — is Microsoft Defender installed?" >&2
  exit 1
fi

if [[ ! -f "$CONF" ]]; then
  echo "error: config not found at $CONF" >&2
  exit 1
fi

# ── Helpers ───────────────────────────────────────────────────────────────────

current_folders() {
  mdatp exclusion list 2>/dev/null | $GREP '^Path:' | $SED 's/Path: "//;s/"//'
}

add_folder() {
  local raw="$1"
  local expanded="${raw/#\~/$HOME}"

  if [[ ! -d "$expanded" ]]; then
    printf "  skip  (not found)   %s\n" "$raw"
    return
  fi

  if current_folders | $GREP -qxF "$expanded"; then
    printf "  skip  (exists)      %s\n" "$raw"
    return
  fi

  if $DRY_RUN; then
    printf "  would add folder    %s\n" "$raw"
  else
    mdatp exclusion folder add --path "$expanded" 2>/dev/null \
      && printf "  added folder        %s\n" "$raw" \
      || printf "  failed (policy?)    %s\n" "$raw"
  fi
}

add_extension() {
  local ext="$1"

  if $DRY_RUN; then
    printf "  would add ext       .%s\n" "$ext"
  else
    mdatp exclusion extension add --extension ".$ext" 2>/dev/null \
      && printf "  added ext           .%s\n" "$ext" \
      || printf "  failed (policy?)    .%s\n" "$ext"
  fi
}

# ── Parse config and apply ────────────────────────────────────────────────────

echo ""
echo "Config: $CONF"
echo ""

current_section=""

while IFS= read -r line; do
  # strip inline comments and trim whitespace
  line="${line%%#*}"
  line="${line#"${line%%[! ]*}"}"  # ltrim
  line="${line%"${line##*[! ]}"}"  # rtrim
  [[ -z "$line" ]] && continue

  type="${line%% *}"
  value="${line#* }"
  value="${value#"${value%%[! ]*}"}"  # ltrim value

  case "$type" in
    folder)
      [[ "$current_section" != "folders" ]] && echo "==> Folders" && current_section="folders"
      add_folder "$value"
      ;;
    ext)
      [[ "$current_section" != "extensions" ]] && echo "" && echo "==> Extensions" && current_section="extensions"
      add_extension "$value"
      ;;
  esac
done < "$CONF"

# ── Summary ───────────────────────────────────────────────────────────────────

echo ""
if $DRY_RUN; then
  echo "Dry run complete. Run without --dry-run to apply."
else
  echo "Done. Current exclusion list:"
  echo ""
  mdatp exclusion list 2>/dev/null
fi

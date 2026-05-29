#!/usr/bin/env bash
# modules/claude-settings/merge.sh — assemble settings.local.json from layers.
set -euo pipefail

MOD_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/platform.sh
source "$MOD_DIR/lib/platform.sh"

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/dotfiles}"
CLAUDE_DIR="${CLAUDE_DIR:-$DOTFILES_DIR/.claude}"
PLATFORM="${PLATFORM:-$(detect_platform)}"

BASE="$CLAUDE_DIR/settings.base.json"
PLATFORM_FILE="$CLAUDE_DIR/settings.${PLATFORM}.json"
OVERRIDE="$CLAUDE_DIR/settings.override.json"
RULES="$CLAUDE_DIR/_merge-config.json"
OUT="$CLAUDE_DIR/settings.local.json"
ATTEST="$CLAUDE_DIR/.settings-attestation"
STRATS_DIR="$MOD_DIR/lib"

# Validate inputs early — if any required file is missing/invalid,
# exit without touching OUT.
for f in "$BASE" "$RULES"; do
    [ -f "$f" ] || { echo "[merge] missing required: $f" >&2; exit 1; }
    jq empty "$f" >/dev/null 2>&1 || { echo "[merge] invalid JSON: $f" >&2; exit 1; }
done
[ -f "$PLATFORM_FILE" ] || { echo "[merge] missing platform file: $PLATFORM_FILE" >&2; exit 1; }
jq empty "$PLATFORM_FILE" >/dev/null 2>&1 || { echo "[merge] invalid JSON: $PLATFORM_FILE" >&2; exit 1; }

# Override is optional — empty {} if missing
if [ -f "$OVERRIDE" ]; then
    jq empty "$OVERRIDE" >/dev/null 2>&1 || { echo "[merge] invalid JSON: $OVERRIDE" >&2; exit 1; }
fi

TMP=$(mktemp "${OUT}.XXXXXX")
trap 'rm -f "$TMP"' EXIT

# Step 1: base ⊕ platform
PHASE1=$(mktemp)
jq -n --slurpfile base "$BASE" \
      --slurpfile platform "$PLATFORM_FILE" \
      --slurpfile rules "$RULES" \
      "include \"strategies\" {search: \"$STRATS_DIR\"}; merge_with_rules(\$base[0]; \$platform[0]; \$rules[0])" \
      > "$PHASE1"

# Step 2: ⊕ override
if [ -f "$OVERRIDE" ]; then
    jq -n --slurpfile prev "$PHASE1" \
          --slurpfile o "$OVERRIDE" \
          --slurpfile rules "$RULES" \
          "include \"strategies\" {search: \"$STRATS_DIR\"}; merge_with_rules(\$prev[0]; \$o[0]; \$rules[0])" \
          > "$TMP"
else
    cp "$PHASE1" "$TMP"
fi
rm -f "$PHASE1"

# Step 3: atomic write
# Note: no env-var substitution — Claude Code resolves $VAR in settings.json
# itself at runtime. Substituting here would expand secrets to disk AND
# destroy the `$schema` key.
mv "$TMP" "$OUT"
trap - EXIT

# Step 4: attestation (SHA of inputs)
{
    sha256sum "$BASE" "$PLATFORM_FILE" "$RULES" 2>/dev/null \
      || shasum -a 256 "$BASE" "$PLATFORM_FILE" "$RULES" 2>/dev/null
    if [ -f "$OVERRIDE" ]; then
        sha256sum "$OVERRIDE" 2>/dev/null || shasum -a 256 "$OVERRIDE" 2>/dev/null
    fi
} | { sha256sum 2>/dev/null || shasum -a 256; } | awk '{print $1}' > "$ATTEST"

echo "[merge] wrote $OUT (platform=$PLATFORM)"

# Best-effort Cursor alignment from shared agent-core.
SYNC_SCRIPT="$DOTFILES_DIR/scripts/agent-core-sync.sh"
if [ -x "$SYNC_SCRIPT" ]; then
    if "$SYNC_SCRIPT" --quiet; then
        echo "[merge] synced Cursor agent core"
    else
        echo "[merge] warn: agent-core-sync failed (continuing)" >&2
    fi
fi

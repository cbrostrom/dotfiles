#!/usr/bin/env bash
# Show diff between settings.local.json and settings.base.json.
# Use this to identify local changes worth promoting back to base.
#
# Workflow for promoting a change:
#   1. Run this script to see what's different
#   2. Edit settings.base.json with the change you want shared
#   3. git add .config/zed/settings.base.json && git commit
#   4. Other machines pick it up on next: bootstrap.sh --update
#      (their local values are preserved, new base key is added)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ZED_SOURCE="$SCRIPT_DIR/.config/zed"
BASE="$ZED_SOURCE/settings.base.json"
LOCAL="$ZED_SOURCE/settings.local.json"

if [[ ! -f "$LOCAL" ]]; then
    echo "No settings.local.json found — nothing to diff"
    exit 0
fi

# Pretty-print both for clean diff (strips jq's normalization noise if possible)
if command -v jq >/dev/null 2>&1; then
    BASE_PP="$(jq . "$BASE")"
    LOCAL_PP="$(jq . "$LOCAL")"
else
    BASE_PP="$(cat "$BASE")"
    LOCAL_PP="$(cat "$LOCAL")"
fi

echo "=== diff: settings.base.json (−) vs settings.local.json (+) ==="
diff <(echo "$BASE_PP") <(echo "$LOCAL_PP") || true

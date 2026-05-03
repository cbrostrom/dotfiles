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

# Pretty-print both via python3 (handles JSONC // comments)
pp_jsonc() {
    python3 - "$1" <<'PYEOF'
import json, sys, re

def strip_jsonc(text):
    text = re.sub(r'^\s*//[^\n]*', '', text, flags=re.MULTILINE)
    text = re.sub(r'/\*.*?\*/', '', text, flags=re.DOTALL)
    text = re.sub(r',(\s*[}\]])', r'\1', text)
    return text

with open(sys.argv[1], encoding='utf-8') as f:
    print(json.dumps(json.loads(strip_jsonc(f.read())), indent=4, ensure_ascii=False))
PYEOF
}

BASE_PP="$(pp_jsonc "$BASE")"
LOCAL_PP="$(pp_jsonc "$LOCAL")"

echo "=== diff: settings.base.json (−) vs settings.local.json (+) ==="
diff <(echo "$BASE_PP") <(echo "$LOCAL_PP") || true

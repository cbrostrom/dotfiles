#!/usr/bin/env bash
# Show diff between settings.base.json and the live VSCodium settings.json on this machine.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SRC="$SCRIPT_DIR/.config/vscodium"
BASE="$SRC/settings.base.json"

_vscodium_live() {
    if grep -qi microsoft /proc/version 2>/dev/null; then
        echo "/mnt/c/Users/${USERNAME:-$(whoami)}/AppData/Roaming/VSCodium/User/settings.json"
    elif [[ "$(uname -s)" == "Darwin" ]]; then
        echo "$HOME/Library/Application Support/VSCodium/User/settings.json"
    else
        echo "$HOME/.config/VSCodium/User/settings.json"
    fi
}

LIVE="$(_vscodium_live)"

if [[ ! -f "$LIVE" ]]; then
    echo "No live settings found: $LIVE"
    exit 0
fi

# Keys injected at install time — strip from both sides before diffing.
PLATFORM_KEYS='["git.path"]'

pp_json() {
    local file="$1"
    local skip_json="$2"
    python3 - "$file" "$skip_json" <<'PYEOF'
import json, sys, re

def strip_jsonc(text):
    text = re.sub(r'^\s*//[^\n]*', '', text, flags=re.MULTILINE)
    text = re.sub(r'/\*.*?\*/', '', text, flags=re.DOTALL)
    text = re.sub(r',(\s*[}\]])', r'\1', text)
    return text

skip_keys = json.loads(sys.argv[2])
with open(sys.argv[1], encoding='utf-8') as f:
    d = json.loads(strip_jsonc(f.read()))
for k in skip_keys:
    d.pop(k, None)
print(json.dumps(d, indent=4, ensure_ascii=False, sort_keys=True))
PYEOF
}

BASE_PP="$(pp_json "$BASE" '[]')"
LIVE_PP="$(pp_json "$LIVE" "$PLATFORM_KEYS")"

echo "=== diff: settings.base.json (−) vs live settings.json (+) ==="
diff <(echo "$BASE_PP") <(echo "$LIVE_PP") || true

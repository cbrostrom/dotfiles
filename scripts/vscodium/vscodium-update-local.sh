#!/usr/bin/env bash
# Pull live VSCodium settings back into settings.base.json.
# Strips platform-specific keys (git.path). Shows diff and prompts before writing.
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
info()    { echo -e "${BLUE}[vscodium-update]${NC} $1"; }
success() { echo -e "${GREEN}[vscodium-update]${NC} $1"; }
warning() { echo -e "${YELLOW}[vscodium-update]${NC} $1"; }
error()   { echo -e "${RED}[vscodium-update]${NC} $1" >&2; }

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
    error "No live settings found: $LIVE"
    exit 1
fi

if [[ ! -f "$BASE" ]]; then
    error "Base not found: $BASE"
    exit 1
fi

# Keys that are platform-specific and should never be written to base.json.
STRIP_KEYS='["git.path"]'

merge_live_into_base() {
    python3 - "$BASE" "$LIVE" "$STRIP_KEYS" <<'PYEOF'
import json, sys, re

def strip_jsonc(text):
    text = re.sub(r'^\s*//[^\n]*', '', text, flags=re.MULTILINE)
    text = re.sub(r'/\*.*?\*/', '', text, flags=re.DOTALL)
    text = re.sub(r',(\s*[}\]])', r'\1', text)
    return text

def deep_merge(base, override):
    result = dict(base)
    for k, v in override.items():
        if k in result and isinstance(result[k], dict) and isinstance(v, dict):
            result[k] = deep_merge(result[k], v)
        else:
            result[k] = v
    return result

strip_keys = json.loads(sys.argv[3])

with open(sys.argv[1], encoding='utf-8') as f:
    base = json.loads(strip_jsonc(f.read()))
with open(sys.argv[2], encoding='utf-8') as f:
    live = json.loads(f.read())

for k in strip_keys:
    live.pop(k, None)

merged = deep_merge(base, live)
print(json.dumps(merged, indent=2, ensure_ascii=False))
PYEOF
}

pp_json() {
    python3 - "$1" "$2" <<'PYEOF'
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
print(json.dumps(d, indent=2, ensure_ascii=False, sort_keys=True))
PYEOF
}

MERGED="$(merge_live_into_base)"
BASE_PP="$(pp_json "$BASE" '[]')"
MERGED_PP="$(echo "$MERGED" | python3 -c "import json,sys; print(json.dumps(json.load(sys.stdin), indent=2, ensure_ascii=False, sort_keys=True))")"

DIFF="$(diff <(echo "$BASE_PP") <(echo "$MERGED_PP") || true)"

if [[ -z "$DIFF" ]]; then
    success "settings.base.json is already up to date with live settings"
    exit 0
fi

echo "=== changes to merge into settings.base.json ==="
echo "$DIFF"
echo ""

read -rp "Write these changes to settings.base.json? [y/N] " ans
if [[ ! "$ans" =~ ^[Yy]$ ]]; then
    warning "Aborted — no changes written"
    exit 0
fi

TMP="$(mktemp "${BASE}.tmp.XXXXXX")"
echo "$MERGED" > "$TMP"
mv "$TMP" "$BASE"
success "settings.base.json updated"
info "Run install-vscodium-config.sh to regenerate settings.local.json and deploy"

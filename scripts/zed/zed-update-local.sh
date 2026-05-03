#!/usr/bin/env bash
# Merge new base changes INTO existing settings.local.json.
# Local values always win on conflicts — machine-specific config is preserved.
# New keys added to base are picked up automatically.
#
# Run automatically by install-zed-config.sh on update.
# Safe to run manually anytime after a git pull.

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
log_info()    { echo -e "${BLUE}[zed-update]${NC} $1"; }
log_success() { echo -e "${GREEN}[zed-update]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[zed-update]${NC} $1"; }
log_error()   { echo -e "${RED}[zed-update]${NC} $1" >&2; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ZED_SOURCE="$SCRIPT_DIR/.config/zed"
BASE="$ZED_SOURCE/settings.base.json"
LOCAL="$ZED_SOURCE/settings.local.json"

if [[ ! -f "$BASE" ]]; then
    log_error "Base not found: $BASE"; exit 1
fi

if [[ ! -f "$LOCAL" ]]; then
    log_warning "No settings.local.json — run install-zed-config.sh first"
    exit 1
fi

# Deep merge: base first, local overrides (local wins all conflicts)
merge_into_local() {
    if command -v jq >/dev/null 2>&1; then
        jq -s '.[0] * .[1]' "$BASE" "$LOCAL"
    elif command -v python3 >/dev/null 2>&1; then
        python3 - "$BASE" "$LOCAL" <<'PYEOF'
import json, sys

def deep_merge(base, override):
    result = dict(base)
    for k, v in override.items():
        if k in result and isinstance(result[k], dict) and isinstance(v, dict):
            result[k] = deep_merge(result[k], v)
        else:
            result[k] = v
    return result

base  = json.load(open(sys.argv[1]))
local = json.load(open(sys.argv[2]))
print(json.dumps(deep_merge(base, local), indent=4, ensure_ascii=False))
PYEOF
    else
        log_error "Neither jq nor python3 found"; exit 1
    fi
}

MERGED="$(merge_into_local)"

# Atomic write via temp file
TMP="$(mktemp "${LOCAL}.tmp.XXXXXX")"
echo "$MERGED" > "$TMP"
mv "$TMP" "$LOCAL"

log_success "settings.local.json updated (base merged in, local values preserved)"

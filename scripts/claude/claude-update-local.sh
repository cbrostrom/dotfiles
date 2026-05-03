#!/usr/bin/env bash
# Merge settings.base.json INTO existing settings.local.json (local wins).
# Run automatically by install-claude-config.sh on update.

set -euo pipefail

BLUE='\033[0;34m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
log_info()    { echo -e "${BLUE}[claude-update]${NC} $1"; }
log_success() { echo -e "${GREEN}[claude-update]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[claude-update]${NC} $1"; }
log_error()   { echo -e "${RED}[claude-update]${NC} $1" >&2; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BASE="$SCRIPT_DIR/.claude/settings.base.json"
LOCAL="$SCRIPT_DIR/.claude/settings.local.json"

[[ -f "$BASE" ]] || { log_error "Base not found: $BASE"; exit 1; }
[[ -f "$LOCAL" ]] || { log_warning "No settings.local.json — run install-claude-config.sh first"; exit 1; }

MERGED="$(python3 - "$BASE" "$LOCAL" <<'PYEOF'
import json, sys

# Arrays under these keys are always taken from base (not merged with local)
BASE_WINS_ARRAYS = {'permissions'}

def deep_merge(base, override, base_wins_arrays=None, _key=None):
    result = dict(base)
    for k, v in override.items():
        if k in result and isinstance(result[k], dict) and isinstance(v, dict):
            result[k] = deep_merge(result[k], v, base_wins_arrays, k)
        elif k in result and isinstance(result[k], list) and _key in (base_wins_arrays or set()):
            pass  # keep base array (e.g. permissions.deny/allow/ask)
        else:
            result[k] = v
    return result

with open(sys.argv[1]) as f: base = json.load(f)
with open(sys.argv[2]) as f: local = json.load(f)
print(json.dumps(deep_merge(base, local, BASE_WINS_ARRAYS), indent=4, ensure_ascii=False))
PYEOF
)"

TMP="$(mktemp "${LOCAL}.tmp.XXXXXX")"
echo "$MERGED" > "$TMP"
mv "$TMP" "$LOCAL"

log_success "settings.local.json updated (base merged in, local values preserved)"

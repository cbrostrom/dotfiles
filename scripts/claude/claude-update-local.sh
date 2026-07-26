#!/usr/bin/env bash
# Merge settings.base.json INTO existing settings.local.json (local wins).
# Run automatically by install-claude-config.sh on update.
#
# Settings Flow:
#   base (shared) -> {darwin,linux,wsl} (OS specific) -> local (machine specific)
#   The OS layer is applied based on the current hostname/env.

set -euo pipefail


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

MERGED="$(python3 - "$BASE" "$LOCAL" "$SCRIPT_DIR/.claude/settings.darwin.json" "$SCRIPT_DIR/.claude/settings.linux.json" "$SCRIPT_DIR/.claude/settings.wsl.json" <<'PYEOF'
import json, sys, os

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

# OS Layering Logic
def get_os_override():
    import platform
    # WSL usually identifies as linux, but we can check for WSL specifically
    if "microsoft" in platform.release().lower() or os.path.exists("/proc/sys/kernel/osrelease"):
        # More robust WSL check
        if "microsoft" in os.getenv("SESS_OS", "unknown").lower() or "microsoft" in platform.release().lower():
             return sys.argv[5] # settings.wsl.json
    if platform.system() == "Darwin":
        return sys.argv[3] # settings.darwin.json
    return sys.argv[4] # settings.linux.json

os_file = get_os_override()
with open(sys.argv[1]) as f: base = json.load(f)
with open(sys.argv[2]) as f: local = json.load(f)

# Apply OS layer first, then local overrides
os_layer = {}
if os_file and os.path.exists(os_file):
    with open(os_file) as f: os_layer = json.load(f)

# Final merge order: Base -> OS Layer -> Local
final = deep_merge(base, os_layer, BASE_WINS_ARRAYS)
final = deep_merge(final, local, BASE_WINS_ARRAYS)

print(json.dumps(final, indent=4, ensure_ascii=False))
PYEOF
)"

TMP="$(mktemp "${LOCAL}.tmp.XXXXXX")"
echo "$MERGED" > "$TMP"
mv "$TMP" "$LOCAL"

log_success "settings.local.json updated (base merged in, local values preserved)"

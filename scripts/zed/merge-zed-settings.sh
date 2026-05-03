#!/usr/bin/env bash
# Merge Zed settings.base.json + settings.local.json → settings.json in Zed config dir.
#
# Usage:
#   ./merge-zed-settings.sh              # merge and write to OS Zed config dir
#   ./merge-zed-settings.sh --dry-run    # print merged JSON, don't write
#
# Local settings file: dotfiles/.config/zed/settings.local.json (gitignored)
# Copy settings.local.example.json as a starting point.

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
log_info()    { echo -e "${BLUE}[zed-merge]${NC} $1"; }
log_success() { echo -e "${GREEN}[zed-merge]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[zed-merge]${NC} $1"; }
log_error()   { echo -e "${RED}[zed-merge]${NC} $1" >&2; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ZED_SOURCE="$SCRIPT_DIR/.config/zed"
BASE="$ZED_SOURCE/settings.base.json"
LOCAL="$ZED_SOURCE/settings.local.json"

DRY_RUN=false
for arg in "$@"; do [[ "$arg" == "--dry-run" ]] && DRY_RUN=true; done

# Resolve target Zed config directory
if [[ "$OSTYPE" == "darwin"* ]]; then
    ZED_TARGET="$HOME/Library/Application Support/Zed"
elif grep -qi microsoft /proc/version 2>/dev/null; then
    WIN_USER="${USERNAME:-christian}"
    ZED_TARGET="/mnt/c/Users/$WIN_USER/AppData/Roaming/Zed"
else
    ZED_TARGET="$HOME/.config/zed"
fi

OUT="$ZED_TARGET/settings.json"

if [[ ! -f "$BASE" ]]; then
    log_error "Base settings not found: $BASE"
    exit 1
fi

# Deep merge using jq (preferred) or python3 fallback
merge_json() {
    local base="$1" local_file="$2"

    if command -v jq >/dev/null 2>&1; then
        jq -s '.[0] * .[1]' "$base" "$local_file"
    elif command -v python3 >/dev/null 2>&1; then
        python3 - "$base" "$local_file" <<'PYEOF'
import json, sys

def deep_merge(base, override):
    result = dict(base)
    for k, v in override.items():
        if k in result and isinstance(result[k], dict) and isinstance(v, dict):
            result[k] = deep_merge(result[k], v)
        else:
            result[k] = v
    return result

base   = json.load(open(sys.argv[1]))
local  = json.load(open(sys.argv[2]))
print(json.dumps(deep_merge(base, local), indent=4, ensure_ascii=False))
PYEOF
    else
        log_error "Neither jq nor python3 found — cannot merge JSON"
        exit 1
    fi
}

if [[ -f "$LOCAL" ]]; then
    log_info "Merging: settings.base.json + settings.local.json"
    MERGED="$(merge_json "$BASE" "$LOCAL")"
else
    log_warning "No settings.local.json found — using base settings only"
    log_info "Create $LOCAL from settings.local.example.json for machine-specific config"
    MERGED="$(cat "$BASE")"
fi

if $DRY_RUN; then
    echo "$MERGED"
    exit 0
fi

if [[ ! -d "$ZED_TARGET" ]]; then
    log_error "Zed config dir not found: $ZED_TARGET"
    exit 1
fi

# Remove symlink if present (switching from old symlink approach)
if [[ -L "$OUT" ]]; then
    log_info "Removing old symlink: $OUT"
    rm "$OUT"
fi

echo "$MERGED" > "$OUT"
log_success "Written: $OUT"

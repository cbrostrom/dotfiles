#!/usr/bin/env bash
# Install Zed config from dotfiles.
#
# settings.json flow:
#   First install : copy settings.base.json → settings.local.json (gitignored)
#   Update        : merge new base changes INTO existing local (local wins conflicts)
#   Symlink       : Zed/settings.json → dotfiles/.config/zed/settings.local.json
#
# Zed writes changes directly to settings.local.json via the symlink.
# To promote a local change back to base: run zed-diff-base.sh, edit base, commit.
#
# keymap.json, rules: symlinked directly (no machine-specific content).

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
log_info()    { echo -e "${BLUE}[zed]${NC} $1"; }
log_success() { echo -e "${GREEN}[zed]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[zed]${NC} $1"; }
log_error()   { echo -e "${RED}[zed]${NC} $1" >&2; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ZED_SOURCE="$SCRIPT_DIR/.config/zed"
BASE="$ZED_SOURCE/settings.base.json"
LOCAL="$ZED_SOURCE/settings.local.json"

# Resolve target Zed config directory
if [[ "$OSTYPE" == "darwin"* ]]; then
    ZED_TARGET="$HOME/Library/Application Support/Zed"
elif grep -qi microsoft /proc/version 2>/dev/null; then
    WIN_USER="${USERNAME:-christian}"
    ZED_TARGET="/mnt/c/Users/$WIN_USER/AppData/Roaming/Zed"
else
    ZED_TARGET="$HOME/.config/zed"
fi

log_info "Source : $ZED_SOURCE"
log_info "Target : $ZED_TARGET"

if [[ ! -d "$ZED_TARGET" ]]; then
    log_warning "Zed config dir not found: $ZED_TARGET — is Zed installed?"
    exit 1
fi

# --- settings.local.json: create or update ---
if [[ ! -f "$LOCAL" ]]; then
    log_info "First install — copying base to settings.local.json"
    cp "$BASE" "$LOCAL"
    log_success "Created settings.local.json from base"
else
    log_info "Updating settings.local.json with new base changes …"
    bash "$SCRIPT_DIR/scripts/zed/zed-update-local.sh"
fi

# Symlink a file (with backup of any existing non-symlink)
link_file() {
    local src="$1" dst="$2" label="$3"
    [[ ! -e "$src" ]] && { log_warning "Source missing, skipping: $src"; return 0; }
    [[ -L "$dst" ]] && rm "$dst"
    if [[ -e "$dst" ]]; then
        local bak="${dst}.backup.$(date +%Y%m%d_%H%M%S)"
        log_warning "Backing up: $dst → $bak"
        mv "$dst" "$bak"
    fi
    ln -sf "$src" "$dst"
    log_success "Linked $label"
}

# settings.json → settings.local.json (Zed writes changes back here directly)
link_file "$LOCAL"                  "$ZED_TARGET/settings.json" "settings.json → settings.local.json"
link_file "$ZED_SOURCE/keymap.json" "$ZED_TARGET/keymap.json"   "keymap.json"
link_file "$ZED_SOURCE/rules"       "$ZED_TARGET/rules"         "rules"

log_success "Zed config installed."
log_info "Promote local changes to base: bash scripts/zed/zed-diff-base.sh"

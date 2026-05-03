#!/usr/bin/env bash
# Install Zed config from dotfiles
# Symlinks settings.json, keymap.json, and rules to the correct OS location.
# Cross-platform: Windows (via WSL), macOS, Linux.

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info()    { echo -e "${BLUE}[zed]${NC} $1"; }
log_success() { echo -e "${GREEN}[zed]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[zed]${NC} $1"; }
log_error()   { echo -e "${RED}[zed]${NC} $1"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ZED_SOURCE="$SCRIPT_DIR/.config/zed"

# Resolve target Zed config directory based on OS
if [[ "$OSTYPE" == "darwin"* ]]; then
    ZED_TARGET="$HOME/Library/Application Support/Zed"
elif grep -qi microsoft /proc/version 2>/dev/null; then
    # WSL — point at Windows Roaming\Zed
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

# Symlink a single file with backup
link_file() {
    local src="$1"
    local dst="$2"
    local label="$3"

    if [[ ! -e "$src" ]]; then
        log_warning "Source missing, skipping: $src"
        return 0
    fi

    if [[ -L "$dst" ]]; then
        rm "$dst"
    elif [[ -e "$dst" ]]; then
        local bak="${dst}.backup.$(date +%Y%m%d_%H%M%S)"
        log_warning "Backing up existing: $dst → $bak"
        mv "$dst" "$bak"
    fi

    ln -sf "$src" "$dst"
    log_success "Linked $label"
}

link_file "$ZED_SOURCE/settings.json" "$ZED_TARGET/settings.json" "settings.json"
link_file "$ZED_SOURCE/keymap.json"   "$ZED_TARGET/keymap.json"   "keymap.json"
link_file "$ZED_SOURCE/rules"         "$ZED_TARGET/rules"         "rules"

log_success "Zed config installed."
log_info "Machine-specific config (engram, extra MCP tokens): see .config/zed/settings.local.example.json"

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
    # Zed supports both XDG (~/.config/zed) and macOS default (~/Library/Application Support/Zed)
    # Prefer whichever already exists (XDG takes precedence if both exist)
    if [[ -d "$HOME/.config/zed" ]]; then
        ZED_TARGET="$HOME/.config/zed"
    else
        ZED_TARGET="$HOME/Library/Application Support/Zed"
    fi
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

# Symlink a file or directory (with backup of any existing non-symlink)
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

# On WSL, Windows Zed cannot follow symlinks to WSL paths.
# Copy read-only files to Windows AppData; settings.local.json is still symlinked
# because it lives on the WSL side and Zed WSL server reads it from there.
copy_file() {
    local src="$1" dst="$2" label="$3"
    [[ ! -e "$src" ]] && { log_warning "Source missing, skipping: $src"; return 0; }
    if [[ -e "$dst" && ! -L "$dst" ]]; then
        local bak="${dst}.backup.$(date +%Y%m%d_%H%M%S)"
        log_warning "Backing up: $dst → $bak"
        mv "$dst" "$bak"
    fi
    [[ -L "$dst" ]] && rm "$dst"
    cp -r "$src" "$dst"
    log_success "Copied $label"
}

IS_WSL=false
grep -qi microsoft /proc/version 2>/dev/null && IS_WSL=true

# settings.json → settings.local.json (Zed writes changes back here directly)
link_file "$LOCAL"                    "$ZED_TARGET/settings.json" "settings.json → settings.local.json"

if $IS_WSL; then
    copy_file "$ZED_SOURCE/keymap.json"   "$ZED_TARGET/keymap.json"   "keymap.json"
    copy_file "$ZED_SOURCE/rules"         "$ZED_TARGET/rules"         "rules"
else
    link_file "$ZED_SOURCE/keymap.json"   "$ZED_TARGET/keymap.json"   "keymap.json"
    link_file "$ZED_SOURCE/rules"         "$ZED_TARGET/rules"         "rules"
    link_file "$ZED_SOURCE/snippets"      "$ZED_TARGET/snippets"      "snippets/"
    link_file "$ZED_SOURCE/tasks.json"    "$ZED_TARGET/tasks.json"    "tasks.json"
    link_file "$ZED_SOURCE/themes"        "$ZED_TARGET/themes"        "themes/ (custom)"
fi

# themes/ — link each .json file individually so user-installed themes are preserved
if [[ -d "$ZED_SOURCE/themes" ]]; then
    mkdir -p "$ZED_TARGET/themes"
    for theme_src in "$ZED_SOURCE/themes"/*.json; do
        [[ -f "$theme_src" ]] || continue
        link_file "$theme_src" "$ZED_TARGET/themes/$(basename "$theme_src")" "themes/$(basename "$theme_src")"
    done
fi

log_success "Zed config installed."
log_info "Promote local changes to base: bash scripts/zed/zed-diff-base.sh"

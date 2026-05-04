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

IS_WSL=false
grep -qi microsoft /proc/version 2>/dev/null && IS_WSL=true

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
fi

# On WSL: merge Windows settings.json into local BEFORE base merge.
# This preserves any UI changes the user made in Zed on Windows.
WIN_SETTINGS="$ZED_TARGET/settings.json"
if $IS_WSL && [[ -f "$WIN_SETTINGS" && ! -L "$WIN_SETTINGS" ]]; then
    log_info "Merging Windows settings into local (Windows UI changes preserved)…"
    python3 - "$WIN_SETTINGS" "$LOCAL" <<'PYEOF'
import json, sys, re

def strip_jsonc(text):
    text = re.sub(r'^\s*//[^\n]*', '', text, flags=re.MULTILINE)
    text = re.sub(r'/\*.*?\*/', '', text, flags=re.DOTALL)
    text = re.sub(r',(\s*[}\]])', r'\1', text)
    return text

def load_jsonc(path):
    with open(path, encoding='utf-8') as f:
        return json.loads(strip_jsonc(f.read()))

def deep_merge(base, override):
    result = dict(base)
    for k, v in override.items():
        if k in result and isinstance(result[k], dict) and isinstance(v, dict):
            result[k] = deep_merge(result[k], v)
        else:
            result[k] = v
    return result

win    = load_jsonc(sys.argv[1])
local  = load_jsonc(sys.argv[2])
# local first, then Windows overrides (Windows UI changes win)
merged = deep_merge(local, win)
with open(sys.argv[2], 'w', encoding='utf-8') as f:
    json.dump(merged, f, indent=4, ensure_ascii=False)
PYEOF
    log_success "Windows settings merged into local"
fi

log_info "Updating settings.local.json with new base changes…"
bash "$SCRIPT_DIR/scripts/zed/zed-update-local.sh"

# Symlink a file or directory (replaces any existing non-symlink without backup —
# git is the backup for dotfiles-tracked files).
link_file() {
    local src="$1" dst="$2" label="$3"
    [[ ! -e "$src" ]] && { log_warning "Source missing, skipping: $src"; return 0; }
    [[ -L "$dst" ]] && rm "$dst"
    [[ -e "$dst" ]] && rm -rf "$dst"
    ln -sf "$src" "$dst"
    log_success "Linked $label"
}

# On WSL, Windows Zed cannot follow symlinks to WSL paths — copy instead.
# No backups: git tracks dotfiles; Windows edits are promoted via reverse_sync_if_newer.
copy_file() {
    local src="$1" dst="$2" label="$3"
    [[ ! -e "$src" ]] && { log_warning "Source missing, skipping: $src"; return 0; }
    [[ -L "$dst" ]] && rm "$dst"
    if [[ -e "$dst" ]] && diff -rq "$src" "$dst" >/dev/null 2>&1; then
        log_success "Copied $label (unchanged)"
        return 0
    fi
    cp -r "$src" "$dst"
    log_success "Copied $label"
}

# For git-tracked files that users also edit in Zed on Windows: if the Windows
# version is newer than the dotfiles version, promote it back to dotfiles.
# Promotes keymap.json and tasks.json (no machine-specific content).
reverse_sync_if_newer() {
    local src="$1" win="$2" label="$3"
    [[ ! -f "$win" ]] && return 0
    [[ ! -f "$src" ]] && return 0
    diff -q "$src" "$win" >/dev/null 2>&1 && return 0  # identical — skip
    local src_ts win_ts
    src_ts=$(stat -c '%Y' "$src" 2>/dev/null || stat -f '%m' "$src" 2>/dev/null)
    win_ts=$(stat -c '%Y' "$win" 2>/dev/null || stat -f '%m' "$win" 2>/dev/null)
    if (( win_ts > src_ts )); then
        cp "$win" "$src"
        log_success "Promoted $label from Windows → dotfiles (Windows was newer)"
    fi
}

if $IS_WSL; then
    # Windows Zed cannot follow WSL symlinks — copy everything.
    # For user-editable files (keymap, tasks): promote from Windows first if newer,
    # so edits made in Zed on Windows aren't silently overwritten.
    reverse_sync_if_newer "$ZED_SOURCE/keymap.json" "$ZED_TARGET/keymap.json" "keymap.json"
    reverse_sync_if_newer "$ZED_SOURCE/tasks.json"  "$ZED_TARGET/tasks.json"  "tasks.json"

    copy_file "$LOCAL"                    "$ZED_TARGET/settings.json" "settings.json (copy)"
    copy_file "$ZED_SOURCE/keymap.json"   "$ZED_TARGET/keymap.json"   "keymap.json"
    copy_file "$ZED_SOURCE/tasks.json"    "$ZED_TARGET/tasks.json"    "tasks.json"
    copy_file "$ZED_SOURCE/rules"         "$ZED_TARGET/rules"         "rules"
    # Copy each theme individually (Windows cannot follow WSL symlinks)
    if [[ -d "$ZED_SOURCE/themes" ]]; then
        [[ -L "$ZED_TARGET/themes" ]] && rm "$ZED_TARGET/themes"
        mkdir -p "$ZED_TARGET/themes"
        for theme_src in "$ZED_SOURCE/themes"/*.json; do
            [[ -f "$theme_src" ]] || continue
            copy_file "$theme_src" "$ZED_TARGET/themes/$(basename "$theme_src")" "themes/$(basename "$theme_src")"
        done
    fi
else
    # Mac/Linux: symlinks work — Zed writes back through symlink to settings.local.json
    link_file "$LOCAL"                    "$ZED_TARGET/settings.json" "settings.json → settings.local.json"
    link_file "$ZED_SOURCE/keymap.json"   "$ZED_TARGET/keymap.json"   "keymap.json"
    link_file "$ZED_SOURCE/rules"         "$ZED_TARGET/rules"         "rules"
    link_file "$ZED_SOURCE/snippets"      "$ZED_TARGET/snippets"      "snippets/"
    link_file "$ZED_SOURCE/tasks.json"    "$ZED_TARGET/tasks.json"    "tasks.json"
    # Link each theme individually so user-installed themes in target are preserved
    if [[ -d "$ZED_SOURCE/themes" ]]; then
        mkdir -p "$ZED_TARGET/themes"
        for theme_src in "$ZED_SOURCE/themes"/*.json; do
            [[ -f "$theme_src" ]] || continue
            link_file "$theme_src" "$ZED_TARGET/themes/$(basename "$theme_src")" "themes/$(basename "$theme_src")"
        done
    fi
fi

log_success "Zed config installed."
log_info "Promote settings changes to base: bash scripts/zed/zed-diff-base.sh"

# Write sync timestamp for status display
date -Iseconds > "$SCRIPT_DIR/.zed-sync-ts" 2>/dev/null || true

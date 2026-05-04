#!/usr/bin/env bash
# Install Claude Code config from dotfiles.
#
# settings.json flow:
#   First install : copy settings.local.example.json → settings.local.json,
#                   inject $HOME paths for hook commands
#   Update        : merge new base changes INTO existing local (local wins)
#   Symlink       : ~/.claude/settings.json → dotfiles/.claude/settings.local.json
#
# Token: GITHUB_PERSONAL_ACCESS_TOKEN lives in ~/.local-secrets (sourced by .zshenv)
#        Claude Code inherits it from the shell environment — no need in settings.json
#
# Other symlinks:
#   ~/.claude/CLAUDE.md → dotfiles/.claude/CLAUDE.md
#   ~/.claude/RTK.md    → dotfiles/.claude/RTK.md
#   ~/.claude/hooks/*   → dotfiles/.claude/hooks/*

set -euo pipefail

BLUE='\033[0;34m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
log_info()    { echo -e "${BLUE}[claude]${NC} $1"; }
log_success() { echo -e "${GREEN}[claude]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[claude]${NC} $1"; }
log_error()   { echo -e "${RED}[claude]${NC} $1" >&2; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CLAUDE_SRC="$SCRIPT_DIR/.claude"
LOCAL="$CLAUDE_SRC/settings.local.json"
CLAUDE_DIR="$HOME/.claude"

mkdir -p "$CLAUDE_DIR/hooks"

log_info "Source : $CLAUDE_SRC"
log_info "Target : $CLAUDE_DIR"

# --- settings.local.json: create or update ---
if [[ ! -f "$LOCAL" ]]; then
    log_info "First install — creating settings.local.json from example"
    cp "$CLAUDE_SRC/settings.local.example.json" "$LOCAL"

    # Inject real $HOME path into hook commands
    sed -i.bak "s|HOME_PLACEHOLDER|$HOME|g" "$LOCAL" && rm -f "${LOCAL}.bak"
    log_success "Hook paths set to $HOME/.claude/hooks/"

    # Merge base into fresh local
    bash "$SCRIPT_DIR/scripts/claude/claude-update-local.sh"
else
    log_info "Updating settings.local.json with new base changes…"
    bash "$SCRIPT_DIR/scripts/claude/claude-update-local.sh"
fi

# Ensure statusLine points to combined statusline script
STATUSLINE_SCRIPT="$HOME/.claude/hooks/statusline.sh"
python3 - "$LOCAL" "$STATUSLINE_SCRIPT" <<'PYEOF'
import json, sys
with open(sys.argv[1]) as f:
    d = json.load(f)
target = {"type": "command", "command": f"bash \"{sys.argv[2]}\""}
if d.get('statusLine') != target:
    d['statusLine'] = target
    with open(sys.argv[1], 'w') as f:
        json.dump(d, f, indent=4, ensure_ascii=False)
    print("[claude] statusLine updated")
PYEOF

# --- symlink helper ---
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

link_file "$LOCAL"                          "$CLAUDE_DIR/settings.json"          "settings.json → settings.local.json"
link_file "$CLAUDE_SRC/CLAUDE.md"           "$CLAUDE_DIR/CLAUDE.md"              "CLAUDE.md"
link_file "$CLAUDE_SRC/RTK.md"             "$CLAUDE_DIR/RTK.md"                 "RTK.md"
link_file "$CLAUDE_SRC/hooks/rtk-rewrite.sh"          "$CLAUDE_DIR/hooks/rtk-rewrite.sh"          "hooks/rtk-rewrite.sh"
link_file "$CLAUDE_SRC/hooks/entroly-start.sh"        "$CLAUDE_DIR/hooks/entroly-start.sh"        "hooks/entroly-start.sh"
link_file "$CLAUDE_SRC/hooks/claude-session-check.sh" "$CLAUDE_DIR/hooks/claude-session-check.sh" "hooks/claude-session-check.sh"
link_file "$CLAUDE_SRC/hooks/statusline.sh"           "$CLAUDE_DIR/hooks/statusline.sh"           "hooks/statusline.sh"
link_file "$CLAUDE_SRC/hooks/git-push-guard.sh"       "$CLAUDE_DIR/hooks/git-push-guard.sh"       "hooks/git-push-guard.sh"
link_file "$CLAUDE_SRC/push-whitelist.txt"            "$CLAUDE_DIR/push-whitelist.txt"            "push-whitelist.txt"

# Ensure hooks are executable
chmod +x "$CLAUDE_DIR/hooks/"*.sh 2>/dev/null || true

log_success "Claude config installed."

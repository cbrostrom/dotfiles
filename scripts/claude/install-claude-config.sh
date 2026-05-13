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
        local bak; bak="${dst}.backup.$(date +%Y%m%d_%H%M%S)"
        log_warning "Backing up: $dst → $bak"
        mv "$dst" "$bak"
    fi
    ln -sf "$src" "$dst"
    log_success "Linked $label"
}

# OpenPets opt-in detection.
# OpenPets refuses to write to symlinked Claude memory + settings files
# (it lstat-checks for isSymbolicLink and isFile). When enabled, install
# regular-file shims/copies instead of symlinks for ~/.claude/CLAUDE.md
# and ~/.claude/settings.json so OpenPets can manage them.
#
# Enable via any of:
#   - env: OPENPETS_ENABLED=1 bash install-claude-config.sh
#   - marker file: ~/.claude/.openpets-enabled
#   - app present: /Applications/OpenPets.app
OPENPETS_ENABLED="${OPENPETS_ENABLED:-}"
if [[ -z "$OPENPETS_ENABLED" ]]; then
    if [[ -f "$CLAUDE_DIR/.openpets-enabled" || -d "/Applications/OpenPets.app" ]]; then
        OPENPETS_ENABLED=1
    fi
fi

# --- settings.json install ---
# Default mode: symlink ~/.claude/settings.json → dotfiles/.claude/settings.local.json.
# OpenPets mode: copy dotfiles → ~/.claude/settings.json; on re-run, preserve any
# `--openpets-managed` hook entries already present locally.
if [[ "$OPENPETS_ENABLED" == "1" ]]; then
    dst="$CLAUDE_DIR/settings.json"
    if [[ -L "$dst" ]]; then
        rm "$dst"
        log_info "Removed settings.json symlink (OpenPets mode)"
    fi
    if [[ -f "$dst" ]] && grep -q -- "--openpets-managed" "$dst" 2>/dev/null; then
        python3 - "$LOCAL" "$dst" <<'PYEOF'
import json, sys, os
src, dst = sys.argv[1], sys.argv[2]
with open(src) as f: base = json.load(f)
with open(dst) as f: cur = json.load(f)
def is_managed(entry):
    if not isinstance(entry, dict): return False
    hooks = entry.get("hooks", [])
    if not isinstance(hooks, list): return False
    for h in hooks:
        if isinstance(h, dict) and "--openpets-managed" in (h.get("command", "") or ""):
            return True
    return False
base.setdefault("hooks", {})
for event, matchers in (cur.get("hooks") or {}).items():
    if not isinstance(matchers, list): continue
    managed = [m for m in matchers if is_managed(m)]
    if not managed: continue
    existing = base["hooks"].get(event)
    base["hooks"][event] = (existing if isinstance(existing, list) else []) + managed
with open(dst, "w") as f:
    json.dump(base, f, indent=4, ensure_ascii=False)
PYEOF
        log_success "Merged settings.json (preserved --openpets-managed hooks)"
    else
        cp "$LOCAL" "$dst"
        log_success "Copied settings.json from dotfiles (OpenPets mode)"
    fi
else
    link_file "$LOCAL"                      "$CLAUDE_DIR/settings.json"          "settings.json → settings.local.json"
fi

if [[ "$OPENPETS_ENABLED" == "1" ]]; then
    # Shim: regular file importing dotfiles CLAUDE.md. OpenPets can safely
    # write its managed `@~/.claude/openpets.md` import line into this file.
    dst="$CLAUDE_DIR/CLAUDE.md"
    desired="@$CLAUDE_SRC/CLAUDE.md"
    if [[ -L "$dst" ]]; then
        rm "$dst"
        log_info "Removed existing CLAUDE.md symlink (OpenPets mode)"
    fi
    if [[ ! -f "$dst" ]]; then
        printf '%s\n' "$desired" > "$dst"
        log_success "Wrote CLAUDE.md shim → $desired"
    elif ! grep -qxF "$desired" "$dst"; then
        # Preserve existing content (likely OpenPets managed block); ensure import line present.
        printf '%s\n%s' "$desired" "$(cat "$dst")" > "$dst.new" && mv "$dst.new" "$dst"
        log_success "Prepended dotfiles import to existing CLAUDE.md shim"
    else
        log_info "CLAUDE.md shim already current"
    fi
else
    link_file "$CLAUDE_SRC/CLAUDE.md"       "$CLAUDE_DIR/CLAUDE.md"              "CLAUDE.md"
fi

link_file "$CLAUDE_SRC/RTK.md"             "$CLAUDE_DIR/RTK.md"                 "RTK.md"
link_file "$CLAUDE_SRC/hooks/rtk-rewrite.sh"          "$CLAUDE_DIR/hooks/rtk-rewrite.sh"          "hooks/rtk-rewrite.sh"
link_file "$CLAUDE_SRC/hooks/entroly-start.sh"        "$CLAUDE_DIR/hooks/entroly-start.sh"        "hooks/entroly-start.sh"
link_file "$CLAUDE_SRC/hooks/claude-session-check.sh" "$CLAUDE_DIR/hooks/claude-session-check.sh" "hooks/claude-session-check.sh"
link_file "$CLAUDE_SRC/hooks/statusline.sh"           "$CLAUDE_DIR/hooks/statusline.sh"           "hooks/statusline.sh"
link_file "$CLAUDE_SRC/hooks/git-push-guard.sh"       "$CLAUDE_DIR/hooks/git-push-guard.sh"       "hooks/git-push-guard.sh"
link_file "$CLAUDE_SRC/hooks/effort-classifier.sh"    "$CLAUDE_DIR/hooks/effort-classifier.sh"    "hooks/effort-classifier.sh"
link_file "$CLAUDE_SRC/push-whitelist.txt"            "$CLAUDE_DIR/push-whitelist.txt"            "push-whitelist.txt"

# Skills directory — symlinked so new installs are auto-tracked in dotfiles
if [ -d "$CLAUDE_DIR/skills" ] && [ ! -L "$CLAUDE_DIR/skills" ]; then
    mv "$CLAUDE_DIR/skills" "$CLAUDE_DIR/skills.backup.$(date +%Y%m%d_%H%M%S)"
    log_warning "Backed up existing skills to ~/.claude/skills.backup.*"
fi
ln -sfn "$CLAUDE_SRC/skills" "$CLAUDE_DIR/skills"
log_success "Linked skills/ → dotfiles"

# Ensure hooks are executable
chmod +x "$CLAUDE_DIR/hooks/"*.sh 2>/dev/null || true

# Pull Claude memory files + desktop config from dotfiles
log_info "Running claude-sync pull..."
bash "$SCRIPT_DIR/scripts/claude/claude-sync.sh" pull

# Install / sync plugins declared in settings.local.json
log_info "Running claude plugin install..."
bash "$SCRIPT_DIR/scripts/claude/install-claude-plugins.sh" || \
    log_warning "plugin install reported errors (non-fatal)"

# Install plannotator CLI binary (used by plannotator plugin hooks)
if grep -q '"plannotator@plannotator": true' "$LOCAL" 2>/dev/null; then
    log_info "Installing plannotator binary..."
    bash "$SCRIPT_DIR/scripts/claude/install-plannotator.sh" || \
        log_warning "plannotator binary install reported errors (non-fatal)"
fi

# Device snapshot — .claude/devices/ is gitignored so this is safe to run on
# every install without dirtying the worktree.
log_info "Writing device snapshot…"
bash "$SCRIPT_DIR/scripts/claude/device-snapshot.sh" write || \
    log_warning "device-snapshot write failed (non-fatal)"

log_success "Claude config installed."

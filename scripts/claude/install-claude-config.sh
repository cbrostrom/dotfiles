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

mkdir -p "$CLAUDE_DIR/hooks" "$CLAUDE_DIR/commands"

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

# --- aislop hooks: patch settings.local.json if aislop binary is present ---
# CC hooks format: each event key → list of block objects [{matcher, hooks:[]}]
if command -v aislop >/dev/null 2>&1; then
    python3 - "$LOCAL" <<'PYEOF'
import json, sys

path = sys.argv[1]
with open(path) as f:
    d = json.load(f)

hooks = d.setdefault("hooks", {})

entries = [
    ("PostToolUse", {"matcher": "Edit|Write|MultiEdit",
                     "hooks": [{"type": "command", "command": "aislop hook claude"}]}),
    ("Stop",        {"matcher": "",
                     "hooks": [{"type": "command", "command": "aislop hook claude --stop"}]}),
    ("FileChanged", {"matcher": ".aislop/config.yml|.aislop/rules.yml|package.json",
                     "hooks": [{"type": "command", "command": "aislop hook claude --on-file-changed"}]}),
]

changed = False
for event, block in entries:
    target_cmd = block["hooks"][0]["command"]
    event_blocks = hooks.setdefault(event, [])
    existing_cmds = [h.get("command") for b in event_blocks for h in b.get("hooks", [])]
    if target_cmd in existing_cmds:
        print(f"\033[0;34m[claude]\033[0m aislop: {event} hook already present")
    else:
        event_blocks.append(block)
        changed = True
        print(f"\033[0;32m[claude]\033[0m aislop: added {event} hook")

if changed:
    with open(path, "w") as f:
        json.dump(d, f, indent=4, ensure_ascii=False)
        f.write("\n")
PYEOF
else
    log_warning "aislop not found — skipping hook patch (install via: brew install scanaislop/tap/aislop)"
fi

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

# --- settings.json + CLAUDE.md install ---
link_file "$LOCAL"                      "$CLAUDE_DIR/settings.json"          "settings.json → settings.local.json"
link_file "$CLAUDE_SRC/CLAUDE.md"       "$CLAUDE_DIR/CLAUDE.md"              "CLAUDE.md"
link_file "$CLAUDE_SRC/AISLOP.md"       "$CLAUDE_DIR/AISLOP.md"              "AISLOP.md"

link_file "$CLAUDE_SRC/RTK.md"             "$CLAUDE_DIR/RTK.md"                 "RTK.md"
link_file "$CLAUDE_SRC/hooks/statusline.sh"           "$CLAUDE_DIR/hooks/statusline.sh"           "hooks/statusline.sh"
link_file "$CLAUDE_SRC/hooks/git-push-guard.sh"       "$CLAUDE_DIR/hooks/git-push-guard.sh"       "hooks/git-push-guard.sh"
link_file "$CLAUDE_SRC/hooks/effort-classifier.sh"    "$CLAUDE_DIR/hooks/effort-classifier.sh"    "hooks/effort-classifier.sh"
link_file "$CLAUDE_SRC/push-whitelist.txt"            "$CLAUDE_DIR/push-whitelist.txt"            "push-whitelist.txt"
link_file "$CLAUDE_SRC/commands/sh.md"                "$CLAUDE_DIR/commands/sh.md"                "commands/sh.md"

# Shared rules (engram-graphiti lives in .shared-rules/ so Cursor can also link it)
SHARED_RULES="$SCRIPT_DIR/.shared-rules"
if [[ -d "$SHARED_RULES" ]]; then
    link_file "$SHARED_RULES/engram-graphiti.md" "$CLAUDE_DIR/engram-graphiti.md" "engram-graphiti.md"
fi

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

# Install Cursor config from dotfiles.
#
# Symlinks/Copies:
#   ~/.cursor/hooks/*.sh  → dotfiles/.cursor/hooks/*.sh
#   ~/.cursor/rules/*.mdc → dotfiles/.cursor/rules/*.mdc
#
# hooks.json patches (idempotent):
#   sessionStart  → brain-load.sh through run-hook.sh
#   preToolUse    → rtk hook cursor through run-hook.sh
#   afterFileEdit → aislop hook cursor through run-hook.sh, if aislop installed
#   stop          → vault-save.sh through run-hook.sh
#   preCompact    → brain-save-inject.sh through run-hook.sh
#   cleanup       → remove dead Code Island and legacy lean-ctx/rtk adapters
set -euo pipefail

BLUE='\033[0;34m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
info()    { echo -e "${BLUE}[cursor]${NC} $1"; }
success() { echo -e "${GREEN}[cursor]${NC} $1"; }
warn()    { echo -e "${YELLOW}[cursor]${NC} $1"; }

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CURSOR_SRC="$DOTFILES/.cursor"
CURSOR_DIR=""

# --- WSL Host Target Detection ---
if grep -q Microsoft /proc/version 2>/dev/null; then
    info "WSL detected. Targeting Windows host for Cursor config."
    # Get Windows username from /etc/wsl.conf or by attempting to find the User folder in /mnt/c
    # Fallback to standard Windows user path pattern if needed
    WIN_USER=$(grep "user" /etc/wsl.conf 2>/dev/null | awk '{print $2}' || echo "$USER")
    # Most common WSL setup: /mnt/c/Users/<User>/AppData/Roaming/Cursor
    CURSOR_DIR="/mnt/c/Users/$WIN_USER/AppData/Roaming/Cursor"
    
    # Verification: ensure the target directory actually exists
    if [[ ! -d "$CURSOR_DIR" ]]; then
        warn "Cursor directory not found at $CURSOR_DIR. Checking alternative paths..."
        # Try to find the directory by globbing common Windows paths
        for alt in /mnt/c/Users/*/AppData/Roaming/Cursor; do
            if [[ -d "$alt" ]]; then
                CURSOR_DIR="$alt"
                break
            fi
        done
    fi
fi

# Fallback for macOS/Native Linux
if [[ -z "$CURSOR_DIR" ]] || [[ ! -d "$CURSOR_DIR" ]]; then
    CURSOR_DIR="$HOME/.cursor"
fi

info "Targeting Cursor config at: $CURSOR_DIR"
mkdir -p "$CURSOR_DIR/hooks"

# --- Hook symlinks/copies ---
for hook in brain-load.sh run-hook.sh vault-save.sh; do
  src="$CURSOR_SRC/hooks/$hook"
  dst="$CURSOR_DIR/hooks/$hook"
  if [[ ! -f "$src" ]]; then
    warn "Hook source not found: $src — skipping"
    continue
  fi
  chmod +x "$src"
  
  # Symlinks don't work across WSL -> Windows (Plan 9/9P) boundaries for these specific files
  # Use copy for Windows host targets to ensure execution
  if [[ "$CURSOR_DIR" == /mnt/* ]]; then
      cp "$src" "$dst"
      success "Copied hooks/$hook to Windows host"
  else
      ln -sf "$src" "$dst"
      success "Linked hooks/$hook"
  fi
done

# --- Rule symlinks/copies (source of truth: dotfiles/.cursor/rules/) ---
RULES_SRC="$CURSOR_SRC/rules"
RULES_DST="$CURSOR_DIR/rules"
mkdir -p "$RULES_DST"
for rule in core.mdc ponytail.mdc; do
  src="$RULES_SRC/$rule"
  dst="$RULES_DST/$rule"
  if [[ ! -f "$src" ]]; then
    warn "Rule source not found: $src — skipping"
    continue
  fi
  
  if [[ "$CURSOR_DIR" == /mnt/* ]]; then
      cp "$src" "$dst"
      success "Copied rules/$rule to Windows host"
  else
      ln -sf "$src" "$dst"
      success "Linked rules/$rule"
  fi
done

# --- Patch hooks.json: keep managed Cursor hooks lean and seconds-based ---
HOOKS_JSON="$CURSOR_DIR/hooks.json"

if [[ ! -f "$HOOKS_JSON" ]]; then
  info "Creating hooks.json at $HOOKS_JSON"
  printf '{\n  "hooks": {},\n  "version": 1\n}\n' >"$HOOKS_JSON"
fi

python3 - "$HOOKS_JSON" <<'PYEOF'
import json, os, shutil, sys

path = sys.argv[1]
with open(path) as f:
    data = json.load(f)

hooks = data.setdefault("hooks", {})
changed = False

# Check if Claude is disabled via modules.conf
DOTFILES = os.path.expanduser("~/dotfiles")
is_disabled = False
conf_path = os.path.join(DOTFILES, "modules.conf")
if os.path.exists(conf_path):
    with open(conf_path) as f:
        content = f.read()
        if "!claude" in content or "!claude-config" in content:
            is_disabled = True

def managed_command(command):
    legacy = (
        ".codeisland/codeisland-bridge",
        "bash './hooks/rtk-rewrite.sh'",
        "bash './hooks/lean-ctx-rewrite.sh'",
        "rtk hook cursor",
        "aislop hook cursor",
        "bash './hooks/brain-load.sh'",
        "bash './hooks/vault-save.sh'",
    )
    wrapped = (
        "bash './hooks/run-hook.sh' rtk -- rtk hook cursor",
        "bash './hooks/run-hook.sh' aislop -- aislop hook cursor",
        "bash './hooks/run-hook.sh' brain-load -- bash './hooks/brain-load.sh'",
        "bash './hooks/run-hook.sh' vault-save -- bash './hooks/vault-save.sh'",
        "bash './hooks/run-hook.sh' brain-save --",
    )
    return any(part in command for part in legacy) or command in wrapped

def cleanup_event(name):
    global changed
    entries = hooks.get(name, [])
    kept = []
    for entry in entries:
        command = entry.get("command", "")
        # If Claude is disabled, we MUST remove any command referencing .claude
        is_claude = ".claude" in command
        if managed_command(command) or (is_disabled and is_claude):
            changed = True
            continue
        kept.append(entry)
    if kept:
        hooks[name] = kept
    elif name in hooks:
        del hooks[name]
        changed = True

for event in list(hooks):
    cleanup_event(event)

def add_entry(event, entry):
    global changed
    entries = hooks.setdefault(event, [])
    if not any(h.get("command") == entry["command"] for h in entries):
        entries.append(entry)
        changed = True
        print(f"\033[0;32m[cursor]\033[0m Patched hooks.json: added {entry['command']} to {event}")
    else:
        print(f"\033[0;34m[cursor]\033[0m hook already present in {event}: {entry['command']}")

# brain-load: sessionStart
brain_entry = {
    "command": "bash './hooks/run-hook.sh' brain-load -- bash './hooks/brain-load.sh'",
    "timeout": 5,
}
add_entry("sessionStart", brain_entry)

# RTK native hook: preToolUse Shell
rtk_entry = {
    "command": "bash './hooks/run-hook.sh' rtk -- rtk hook cursor",
    "type": "command",
    "matcher": "Shell",
    "timeout": 5,
}
add_entry("preToolUse", rtk_entry)

# aislop: afterFileEdit (only if aislop binary exists)
if shutil.which("aislop"):
    add_entry("afterFileEdit", {
        "command": "bash './hooks/run-hook.sh' aislop -- aislop hook cursor",
        "type": "command",
        "timeout": 5,
        "__aislop": {
            "v": 1,
            "managed": True,
            "hash": "sha256:909500b88282a9d06547652124bcc76c",
        },
    })
else:
    print("\033[1;33m[cursor]\033[0m aislop not found — skipping afterFileEdit patch")

# vault-save: stop (lightweight brain nudge after each task)
add_entry("stop", {
    "command": "bash './hooks/run-hook.sh' vault-save -- bash './hooks/vault-save.sh'",
    "timeout": 5,
})

# brain-save-inject: preCompact — save brain before context is summarized
# Only inject if .claude folder exists and is not disabled in modules.conf
if os.path.exists(f"{DOTFILES}/.claude") and not is_disabled:
    add_entry("preCompact", {
        "command": f"bash './hooks/run-hook.sh' brain-save -- bash '{DOTFILES}/.claude/hooks/brain-save-inject.sh'",
        "timeout": 10,
    })
else:
    print("\033[1;33m[cursor]\033[0m Claude disabled or not found — skipping preCompact brain-save hook")

if changed:
    with open(path, "w") as f:
        json.dump(data, f, indent=2)
        f.write("\n")
PYEOF

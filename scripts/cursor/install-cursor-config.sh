#!/usr/bin/env bash
# Install Cursor config from dotfiles.
#
# Symlinks:
#   ~/.cursor/hooks/*.sh  → dotfiles/.cursor/hooks/*.sh
#
# hooks.json patches (idempotent):
#   sessionStart  → brain-load.sh through run-hook.sh
#   preToolUse    → rtk hook cursor through run-hook.sh
#   afterFileEdit → aislop hook cursor through run-hook.sh, if aislop installed
#   cleanup       → remove dead Code Island and legacy lean-ctx/rtk adapters
set -euo pipefail

BLUE='\033[0;34m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
info()    { echo -e "${BLUE}[cursor]${NC} $1"; }
success() { echo -e "${GREEN}[cursor]${NC} $1"; }
warn()    { echo -e "${YELLOW}[cursor]${NC} $1"; }

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CURSOR_SRC="$DOTFILES/.cursor"
CURSOR_DIR="$HOME/.cursor"

mkdir -p "$CURSOR_DIR/hooks"

# --- Hook symlinks ---
for hook in brain-load.sh run-hook.sh; do
  src="$CURSOR_SRC/hooks/$hook"
  dst="$CURSOR_DIR/hooks/$hook"
  if [[ ! -f "$src" ]]; then
    warn "Hook source not found: $src — skipping"
    continue
  fi
  chmod +x "$src"
  ln -sf "$src" "$dst"
  success "Linked hooks/$hook"
done

# --- Patch hooks.json: keep managed Cursor hooks lean and seconds-based ---
HOOKS_JSON="$CURSOR_DIR/hooks.json"

if [[ ! -f "$HOOKS_JSON" ]]; then
  info "Creating hooks.json at $HOOKS_JSON"
  printf '{\n  "hooks": {},\n  "version": 1\n}\n' >"$HOOKS_JSON"
fi

python3 - "$HOOKS_JSON" <<'PYEOF'
import json, shutil, sys

path = sys.argv[1]
with open(path) as f:
    data = json.load(f)

hooks = data.setdefault("hooks", {})
changed = False

def managed_command(command):
    legacy = (
        ".codeisland/codeisland-bridge",
        "bash './hooks/rtk-rewrite.sh'",
        "bash './hooks/lean-ctx-rewrite.sh'",
        "rtk hook cursor",
        "aislop hook cursor",
        "bash './hooks/brain-load.sh'",
    )
    wrapped = (
        "bash './hooks/run-hook.sh' rtk -- rtk hook cursor",
        "bash './hooks/run-hook.sh' aislop -- aislop hook cursor",
        "bash './hooks/run-hook.sh' brain-load -- bash './hooks/brain-load.sh'",
    )
    return any(part in command for part in legacy) or command in wrapped

def cleanup_event(name):
    global changed
    entries = hooks.get(name, [])
    kept = []
    for entry in entries:
        command = entry.get("command", "")
        if managed_command(command):
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

if changed:
    with open(path, "w") as f:
        json.dump(data, f, indent=2)
        f.write("\n")
PYEOF

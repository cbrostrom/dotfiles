#!/usr/bin/env bash
# Install Cursor config from dotfiles.
#
# Symlinks:
#   ~/.cursor/hooks/*.sh  → dotfiles/.cursor/hooks/*.sh
#
# hooks.json patches (idempotent — never clobbers existing hooks):
#   sessionStart  → brain-load.sh (vault brain context injection)
#   preToolUse    → rtk-rewrite.sh (Shell command token compression)
#   afterFileEdit → aislop hook cursor (quality gate, if aislop installed)
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
for hook in brain-load.sh rtk-rewrite.sh; do
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

# --- Patch hooks.json: inject brain-load into sessionStart if absent ---
HOOKS_JSON="$CURSOR_DIR/hooks.json"

if [[ ! -f "$HOOKS_JSON" ]]; then
  warn "hooks.json not found at $HOOKS_JSON — skipping patch"
  info "Create it manually or via Cursor Settings → Hooks"
  exit 0
fi

python3 - "$HOOKS_JSON" <<'PYEOF'
import json, sys

path = sys.argv[1]
with open(path) as f:
    data = json.load(f)

hooks = data.setdefault("hooks", {})
changed = False

# brain-load: sessionStart
brain_entry = {"command": "bash './hooks/brain-load.sh'"}
session_hooks = hooks.setdefault("sessionStart", [])
if any(h.get("command") == brain_entry["command"] for h in session_hooks):
    print("\033[0;34m[cursor]\033[0m brain-load already present in sessionStart — no change")
else:
    session_hooks.append(brain_entry)
    changed = True
    print("\033[0;32m[cursor]\033[0m Patched hooks.json: added brain-load to sessionStart")

# rtk-rewrite: preToolUse Shell
rtk_entry = {
    "command": "bash './hooks/rtk-rewrite.sh'",
    "type": "command",
    "matcher": "Shell",
    "timeout": 5000,
}
tool_hooks = hooks.setdefault("preToolUse", [])

# Remove RTK's upstream self-installed Cursor hook if present. The dotfiles hook
# owns the adapter shape and calls the shared rewrite policy instead.
before = len(tool_hooks)
tool_hooks[:] = [h for h in tool_hooks if h.get("command") != "rtk hook cursor"]
if len(tool_hooks) != before:
    changed = True
    print("\033[0;32m[cursor]\033[0m Removed upstream rtk hook cursor from preToolUse")

if any(h.get("command") == rtk_entry["command"] for h in tool_hooks):
    print("\033[0;34m[cursor]\033[0m rtk-rewrite already present in preToolUse — no change")
else:
    tool_hooks.append(rtk_entry)
    changed = True
    print("\033[0;32m[cursor]\033[0m Patched hooks.json: added rtk-rewrite to preToolUse")

# aislop: afterFileEdit (only if aislop binary exists)
import shutil
if shutil.which("aislop"):
    aislop_cmd = "aislop hook cursor"
    edit_hooks = hooks.setdefault("afterFileEdit", [])
    if any(h.get("command") == aislop_cmd for h in edit_hooks):
        print("\033[0;34m[cursor]\033[0m aislop already present in afterFileEdit — no change")
    else:
        edit_hooks.append({"command": aislop_cmd, "type": "command", "timeout": 5000})
        changed = True
        print("\033[0;32m[cursor]\033[0m Patched hooks.json: added aislop to afterFileEdit")
else:
    print("\033[1;33m[cursor]\033[0m aislop not found — skipping afterFileEdit patch")

if changed:
    with open(path, "w") as f:
        json.dump(data, f, indent=2)
        f.write("\n")
PYEOF

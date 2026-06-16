#!/usr/bin/env bash
# Install Cursor config from dotfiles.
#
# Symlinks:
#   ~/.cursor/hooks/brain-load.sh  → dotfiles/.cursor/hooks/brain-load.sh
#
# hooks.json:
#   Patches ~/.cursor/hooks.json to add the brain-load sessionStart entry
#   if it is not already present. Leaves all other hooks intact.
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
for hook in brain-load.sh; do
  src="$CURSOR_SRC/hooks/$hook"
  dst="$CURSOR_DIR/hooks/$hook"
  if [[ ! -f "$src" ]]; then
    warn "Hook source not found: $src — skipping"
    continue
  fi
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

entry = {"command": "bash './hooks/brain-load.sh'"}
hooks = data.setdefault("hooks", {})
session_hooks = hooks.setdefault("sessionStart", [])

if any(h.get("command") == entry["command"] for h in session_hooks):
    print("\033[0;34m[cursor]\033[0m brain-load already present in sessionStart — no change")
    sys.exit(0)

session_hooks.append(entry)

with open(path, "w") as f:
    json.dump(data, f, indent=2)
    f.write("\n")

print("\033[0;32m[cursor]\033[0m Patched hooks.json: added brain-load to sessionStart")
PYEOF

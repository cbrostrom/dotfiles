#!/usr/bin/env bash
# Apply tracked T3 Code config from setup/t3/ to ~/.t3/userdata.
#
#   ./setup/t3.sh
#
# T3 owns its settings files and creates them on first launch, so this script
# merges the tracked top-level keys into them and leaves the rest alone
# (project overrides, source control hosts, window state). Keybindings are
# copied whole, with the previous file kept as keybindings.json.bak.
# The Pi provider points at the curated Paseo launcher (scripts/pi-paseo);
# its model list is discovered through the launcher, so no customModels.

set -euo pipefail

DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
. "$DOTFILES_DIR/setup/lib.sh"

T3_USERDATA="${T3_USERDATA:-$HOME/.t3/userdata}"
T3_SRC="$DOTFILES_DIR/setup/t3"
PI_LAUNCHER="$DOTFILES_DIR/scripts/pi-paseo"

if [[ ! -f "$T3_USERDATA/settings.json" ]]; then
    skip "T3 settings not found ($T3_USERDATA); launch T3 once, then rerun"
    exit 0
fi

# merge_json <target> <overlay> [pi-launcher]: overlay top-level keys, print yes/no.
merge_json() {
    python3 - "$@" <<'PY'
import json
import os
import sys
from tempfile import NamedTemporaryFile

path, overlay_path = sys.argv[1:3]
launcher = sys.argv[3] if len(sys.argv) > 3 else None
with open(path) as f:
    settings = json.load(f)
with open(overlay_path) as f:
    overlay = json.load(f)
before = json.dumps(settings, sort_keys=True)

settings.update(overlay)
if launcher:
    pi = settings.setdefault("providerInstances", {}).setdefault("pi", {"driver": "pi"})
    pi["enabled"] = True
    pi.setdefault("config", {})["binaryPath"] = launcher

if json.dumps(settings, sort_keys=True) == before:
    print("no")
    sys.exit(0)

with NamedTemporaryFile("w", dir=os.path.dirname(path), delete=False) as tmp:
    json.dump(settings, tmp, indent=2)
    tmp.write("\n")
os.replace(tmp.name, path)
print("yes")
PY
}

report() {
    if [[ "$2" == "yes" ]]; then
        ok "T3 $1 updated (restart T3 to apply)"
    else
        ok "T3 $1 already up to date"
    fi
}

report "settings.json (Pi via $PI_LAUNCHER)" \
    "$(merge_json "$T3_USERDATA/settings.json" "$T3_SRC/settings.json" "$PI_LAUNCHER")"

if [[ -f "$T3_USERDATA/client-settings.json" ]]; then
    report "client-settings.json" \
        "$(merge_json "$T3_USERDATA/client-settings.json" "$T3_SRC/client-settings.json")"
else
    skip "T3 client-settings.json not found; rerun after T3 creates it"
fi

kb="$T3_USERDATA/keybindings.json"
if [[ -f "$kb" ]] && cmp -s "$kb" "$T3_SRC/keybindings.json"; then
    ok "T3 keybindings.json already up to date"
else
    [[ -f "$kb" ]] && cp "$kb" "$kb.bak"
    cp "$T3_SRC/keybindings.json" "$kb"
    ok "T3 keybindings.json updated (restart T3 to apply)"
fi

#!/usr/bin/env bash
# Point T3 Code's Pi provider at the curated Paseo launcher (scripts/pi-paseo).
#
#   ./setup/t3.sh
#
# T3 owns settings.json and creates it on first launch, so this script only
# patches providerInstances.pi when the file exists and leaves the rest alone.
# Pi's model list is discovered through the launcher; no customModels needed.

set -euo pipefail

DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
. "$DOTFILES_DIR/setup/lib.sh"

T3_SETTINGS="${T3_SETTINGS:-$HOME/.t3/userdata/settings.json}"
PI_LAUNCHER="$DOTFILES_DIR/scripts/pi-paseo"

if [[ ! -f "$T3_SETTINGS" ]]; then
    skip "T3 settings not found ($T3_SETTINGS); launch T3 once, then rerun"
    exit 0
fi

changed="$(python3 - "$T3_SETTINGS" "$PI_LAUNCHER" <<'PY'
import json
import os
import sys
from tempfile import NamedTemporaryFile

path, launcher = sys.argv[1:]
with open(path) as f:
    settings = json.load(f)
before = json.dumps(settings, sort_keys=True)

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
)"

if [[ "$changed" == "yes" ]]; then
    ok "T3 Pi provider uses $PI_LAUNCHER (restart T3 to apply)"
else
    ok "T3 Pi provider already uses $PI_LAUNCHER"
fi

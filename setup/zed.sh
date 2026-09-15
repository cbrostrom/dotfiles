#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$ROOT/setup/lib.sh"

BASE="$ROOT/setup/zed/settings.base.json"
STATIC="$ROOT/stow/zed/.config/zed"
IS_WSL=false
grep -qi microsoft /proc/version 2>/dev/null && IS_WSL=true

if $IS_WSL; then
    win_user="${USERNAME:-christian}"
    target="/mnt/c/Users/$win_user/AppData/Roaming/Zed"
else
    target="$HOME/.config/zed"
fi
mkdir -p "$target"

python3 - "$BASE" "$target/settings.json" <<'PY'
import json
import re
import sys
from pathlib import Path
from tempfile import NamedTemporaryFile

base_path, target_path = map(Path, sys.argv[1:])


def load(path):
    if not path.exists():
        return {}
    text = path.read_text(encoding="utf-8")
    text = re.sub(r"^\s*//[^\n]*", "", text, flags=re.MULTILINE)
    text = re.sub(r"/\*.*?\*/", "", text, flags=re.DOTALL)
    text = re.sub(r",(\s*[}\]])", r"\1", text)
    return json.loads(text)


def merge(base, local):
    result = dict(base)
    for key, value in local.items():
        if isinstance(value, dict) and isinstance(result.get(key), dict):
            result[key] = merge(result[key], value)
        else:
            result[key] = value
    return result

result = merge(load(base_path), load(target_path))
target_path.parent.mkdir(parents=True, exist_ok=True)
with NamedTemporaryFile("w", encoding="utf-8", dir=target_path.parent, delete=False) as handle:
    json.dump(result, handle, indent=4, ensure_ascii=False)
    handle.write("\n")
    temporary = Path(handle.name)
temporary.replace(target_path)
PY
ok "Zed settings merged without linking mutable state"

if $IS_WSL; then
    for relative in keymap.json tasks.json rules snippets themes; do
        source_path="$STATIC/$relative"
        [[ -e "$source_path" ]] || continue
        rm -rf "${target:?}/$relative"
        cp -R "$source_path" "$target/$relative"
    done
    ok "Zed static config copied to Windows"
fi

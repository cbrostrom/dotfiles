#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
profile="${1:-}"
if [[ -z "$profile" ]]; then
    case "$(uname -s)" in
        Darwin) profile="macos" ;;
        Linux)
            if grep -qi microsoft /proc/version 2>/dev/null; then
                profile="wsl"
            else
                profile="linux"
            fi
            ;;
        *)
            printf 'error: pass a profile\n' >&2
            exit 2
            ;;
    esac
fi

profile_file="$ROOT/profiles/$profile.stow"
[[ -f "$profile_file" ]] || {
    printf 'error: unknown profile: %s\n' "$profile" >&2
    exit 2
}
command -v stow >/dev/null 2>&1 || {
    printf 'error: GNU Stow is not installed\n' >&2
    exit 1
}

python3 - "$ROOT" "$HOME" "$profile_file" <<'PY'
import json
import os
import sys
from pathlib import Path

repo, home, profile_path = map(Path, sys.argv[1:])
stow_dir = repo / "stow"
packages = [
    line.strip()
    for line in profile_path.read_text(encoding="utf-8").splitlines()
    if line.strip() and not line.lstrip().startswith("#")
]
errors = []
checked = 0


def package_entries(package_dir):
    for root, directories, files in os.walk(package_dir, followlinks=False):
        root_path = Path(root)
        for name in list(directories):
            item = root_path / name
            if item.is_symlink():
                yield item.relative_to(package_dir)
                directories.remove(name)
        for name in files:
            yield (root_path / name).relative_to(package_dir)


for package in packages:
    package_dir = stow_dir / package
    if not package_dir.is_dir():
        errors.append(f"missing package: {package}")
        continue
    for relative in package_entries(package_dir):
        checked += 1
        target = home / relative
        if not target.is_symlink():
            errors.append(f"not linked: ~/{relative}")
            continue
        direct = (target.parent / os.readlink(target)).resolve(strict=False)
        try:
            direct.relative_to(stow_dir)
        except ValueError:
            errors.append(f"outside Stow: ~/{relative} -> {direct}")
            continue
        if not target.exists():
            errors.append(f"broken: ~/{relative}")

for relative in (Path(".pi/agent/settings.json"), Path(".paseo/config.json")):
    path = home / relative
    if not path.exists():
        continue
    try:
        json.loads(path.read_text(encoding="utf-8"))
    except (json.JSONDecodeError, OSError) as error:
        errors.append(f"invalid JSON: ~/{relative}: {error}")

print(f"profile={profile_path.stem} packages={len(packages)} links={checked} errors={len(errors)}")
for error in errors:
    print(f"error: {error}")
raise SystemExit(1 if errors else 0)
PY

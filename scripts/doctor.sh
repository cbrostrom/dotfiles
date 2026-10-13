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

python3 - "$ROOT" "$HOME" "$profile_file" "$profile" <<'PY'
import json
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

repo, home, profile_path, profile_name = (
    Path(sys.argv[1]),
    Path(sys.argv[2]),
    Path(sys.argv[3]),
    sys.argv[4],
)
PASEO_PROFILES = frozenset({"macos", "wsl", "cloudbro", "server"})
stow_dir = repo / "stow"
packages = [
    line.strip()
    for line in profile_path.read_text(encoding="utf-8").splitlines()
    if line.strip() and not line.lstrip().startswith("#")
]
errors = []
warnings = []
checked = 0


def package_entries(package_dir):
    for root, directories, files in os.walk(package_dir, followlinks=False):
        root_path = Path(root)
        for name in list(directories):
            item = root_path / name
            if item.is_symlink():
                yield item.relative_to(package_dir)
                directories.remove(name)
        # Runtime artifacts: generated inside the stow tree by setup scripts
        # or tooling (npm deps, zsh caches). Never stow-managed, never linked.
        directories[:] = [d for d in directories if d not in ("node_modules", ".DS_Store")]
        for name in files:
            if name == ".DS_Store" or name.endswith(".zwc") or name.endswith(".swp"):
                continue
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

# Git: ~/.gitconfig includes ~/.gitconfig.local; warn when missing and when
# GitHub HTTPS operations would fall back to an interactive prompt.
if (home / ".gitconfig").is_file() and not (home / ".gitconfig.local").is_file():
    errors.append("missing: ~/.gitconfig.local (copy from .gitconfig.local.example,"
                  " uncomment the credential helper)")
if shutil.which("gh") and subprocess.run(
    ["git", "config", "--get", "credential.https://github.com.helper"],
    capture_output=True, text=True, check=False
).returncode != 0:
    errors.append("no GitHub credential helper configured — uncomment the"
                  " credential block in ~/.gitconfig.local")

# Higgins write-through: when the wrapper exists, require the canonical
# writer VM to be reachable (fail fast -- no silent brain loss).
writer = home / ".local/bin/higgins-writer"
if writer.is_file() and subprocess.run(
    [str(writer), "status"], capture_output=True, text=True, timeout=20,
    check=False
).returncode != 0:
    errors.append("higgins-writer unreachable -- canonical writer VM down?")


def parse_semver_loose(version: str) -> tuple[int, ...]:
    match = re.search(r"(\d+)\.(\d+)\.(\d+)", version)
    if not match:
        return ()
    return tuple(int(part) for part in match.groups())


def semver_at_least(version: str, minimum: str) -> bool:
    left = parse_semver_loose(version)
    right = parse_semver_loose(minimum)
    if not left or not right:
        return True
    return left >= right


def check_paseo() -> None:
    if profile_name not in PASEO_PROFILES:
        return
    fix = (
        "fix: install @getpaseo/cli, run ~/dotfiles/setup/paseo.sh, "
        "set ~/.paseo/fleet-env from sources/paseo/fleet-env.example if the daemon is password-protected"
    )
    if not shutil.which("paseo"):
        errors.append(f"paseo CLI not on PATH ({fix})")
        return

    version_proc = subprocess.run(
        ["paseo", "--version"], capture_output=True, text=True, check=False
    )
    cli_version = (version_proc.stdout or version_proc.stderr or "").strip()
    if cli_version and not semver_at_least(cli_version, "0.11.0"):
        warnings.append(
            f"paseo CLI {cli_version} is below recommended 0.11.0 — npm install -g @getpaseo/cli"
        )

    plugin_ls = subprocess.run(
        ["paseo", "plugin", "ls", "--json"],
        capture_output=True,
        text=True,
        check=False,
    )
    if plugin_ls.returncode != 0:
        errors.append(
            "paseo daemon unreachable or auth failed — "
            f"paseo daemon start; {fix}"
        )
        return

    manifest_path = repo / "sources" / "paseo" / "plugins.json"
    if not manifest_path.is_file():
        errors.append(f"missing Paseo manifest: {manifest_path}")
        return
    try:
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as error:
        errors.append(f"invalid plugins.json: {error}")
        return

    expected = {
        entry["id"]
        for entry in manifest.get("plugins", [])
        if isinstance(entry, dict) and entry.get("id")
    }
    try:
        installed_raw = json.loads(plugin_ls.stdout or "[]")
    except json.JSONDecodeError as error:
        errors.append(f"paseo plugin ls --json parse error: {error}")
        return

    if isinstance(installed_raw, dict):
        installed_list = installed_raw.get("plugins") or installed_raw.get("items") or []
    else:
        installed_list = installed_raw

    installed = set()
    for entry in installed_list:
        if isinstance(entry, str):
            installed.add(entry)
        elif isinstance(entry, dict) and entry.get("id"):
            installed.add(entry["id"])

    missing = sorted(expected - installed)
    extra = sorted(installed - expected)
    if missing:
        errors.append(f"paseo plugins missing: {', '.join(missing)} — run ~/dotfiles/setup/paseo.sh")
    if extra:
        warnings.append(f"paseo plugins not in manifest (orphans?): {', '.join(extra)}")


check_paseo()

print(
    f"profile={profile_path.stem} packages={len(packages)} links={checked} "
    f"errors={len(errors)} warnings={len(warnings)}"
)
for warning in warnings:
    print(f"warning: {warning}")
for error in errors:
    print(f"error: {error}")
raise SystemExit(1 if errors else 0)
PY

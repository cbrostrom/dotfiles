#!/usr/bin/env python3
"""Merge tracked Pi defaults into the live settings."""

from __future__ import annotations

import json
import platform
import sys
from pathlib import Path
from tempfile import NamedTemporaryFile
from typing import Any

RUNTIME_KEYS = {
    "lastChangelogVersion",
    "trackingId",
}

# Seeded from the base only when unset, so a /model choice survives re-runs.
DEFAULT_KEYS = {
    "defaultProvider",
    "defaultModel",
    "defaultThinkingLevel",
}

# Removed from scripts/install/pi-extensions.txt — strip on every settings merge.
REMOVED_PACKAGES = frozenset(
    {
        "npm:pi-tool-display",
        "npm:@ollama/pi-web-search",
        "npm:pi-ollama-cloud",
        "npm:pi-blackhole",
        "npm:pi-mcp-adapter",
        "git:github.com/v2nic/pi-caveman",
        "npm:context-mode",
        "npm:pi-cmux",
        "npm:pi-paster",
        "npm:@diegopetrucci/pi-notify",
        "npm:@juanibiapina/pi-powerbar",
        "npm:@narumitw/pi-tui-kit",
        "npm:@nguyenquangthai/pi-todo",
        "npm:@thisux/pi-double-esc-clear",
    }
)

MACOS_ONLY_PACKAGES = frozenset({"npm:@narumitw/pi-caffeinate"})


def read_json(path: Path, default: dict[str, Any]) -> dict[str, Any]:
    if not path.exists():
        return default
    try:
        with path.open(encoding="utf-8") as handle:
            return json.load(handle)
    except (json.JSONDecodeError, OSError) as error:
        print(f"[pi] warning: cannot read {path}: {error}", file=sys.stderr)
        return default


def write_json(path: Path, value: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with NamedTemporaryFile("w", encoding="utf-8", dir=path.parent, delete=False) as handle:
        json.dump(value, handle, indent=2)
        handle.write("\n")
        temporary = Path(handle.name)
    temporary.replace(path)


def merge_settings(base: dict[str, Any], local: dict[str, Any]) -> dict[str, Any]:
    result = dict(local)
    for key, value in base.items():
        if key in RUNTIME_KEYS or key == "packages":
            continue
        if key in DEFAULT_KEYS:
            result.setdefault(key, value)
        elif isinstance(value, dict) and isinstance(result.get(key), dict):
            result[key] = {**result[key], **value}
        else:
            result[key] = value

    packages = list(local.get("packages", []))
    for package in base.get("packages", []):
        if package not in packages:
            packages.append(package)
    result["packages"] = packages
    return result


def prune_packages(settings: dict[str, Any]) -> None:
    excluded = set(REMOVED_PACKAGES)
    if platform.system() != "Darwin":
        excluded |= MACOS_ONLY_PACKAGES
    # Local settings may carry non-string package entries (e.g. dicts); leave
    # anything unhashable untouched and exclude only hashable matches.
    kept: list[Any] = []
    for package in settings.get("packages", []):
        try:
            drop = package in excluded
        except TypeError:
            drop = False
        if not drop:
            kept.append(package)
    settings["packages"] = kept


def main() -> int:
    if len(sys.argv) != 3:
        print("usage: settings.py BASE SETTINGS", file=sys.stderr)
        return 2

    base_path, settings_path = map(Path, sys.argv[1:])
    settings = merge_settings(read_json(base_path, {}), read_json(settings_path, {}))
    # A stale model allowlist hides new models and warns at startup; Pi offers all when unset.
    settings.pop("enabledModels", None)
    prune_packages(settings)
    print(f"[pi] default={settings.get('defaultProvider')}/{settings.get('defaultModel')}")
    write_json(settings_path, settings)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

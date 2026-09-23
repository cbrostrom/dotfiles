#!/usr/bin/env python3
"""Merge tracked Pi defaults and resolve host-specific model policy."""

from __future__ import annotations

import json
import os
import socket
import subprocess
import sys
from datetime import datetime
from pathlib import Path
from tempfile import NamedTemporaryFile
from typing import Any

RUNTIME_KEYS = {
    "lastChangelogVersion",
    "trackingId",
    "enabledModels",
    "defaultProvider",
    "defaultModel",
    "defaultThinkingLevel",
}

# Removed from scripts/install/pi-extensions.txt — strip on every settings merge.
REMOVED_PACKAGES = frozenset({"npm:pi-tool-display"})


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
        if isinstance(value, dict) and isinstance(result.get(key), dict):
            result[key] = {**result[key], **value}
        else:
            result[key] = value

    packages = list(local.get("packages", []))
    for package in base.get("packages", []):
        if package not in packages:
            packages.append(package)
    result["packages"] = packages
    return result


def host_entries(policy: dict[str, Any]) -> dict[str, dict[str, Any]]:
    hosts = policy.get("hosts", {})
    return {
        name: config
        for name, config in hosts.items()
        if isinstance(config, dict) and isinstance(config.get("groups"), list)
    }


def resolve_host(policy: dict[str, Any], host_path: Path) -> tuple[str, dict[str, Any]]:
    hosts = host_entries(policy)
    saved = read_json(host_path, {})
    requested = os.environ.get("PI_HOST_SLUG")
    hostname = socket.gethostname().split(".")[0]

    if requested in hosts:
        slug = requested
    elif saved.get("slug") in hosts:
        slug = saved["slug"]
    else:
        slug = next(
            (name for name, config in hosts.items() if hostname in config.get("aliases", [])),
            "default-desktop" if "default-desktop" in hosts else next(iter(hosts)),
        )

    write_json(
        host_path,
        {
            "slug": slug,
            "hostname": hostname,
            "resolvedAt": datetime.now().isoformat(timespec="seconds"),
        },
    )
    return slug, hosts[slug]


def available_models() -> set[str]:
    try:
        result = subprocess.run(
            ["pi", "--list-models"],
            capture_output=True,
            text=True,
            timeout=15,
            check=False,
        )
    except (subprocess.TimeoutExpired, FileNotFoundError, OSError) as error:
        print(f"[pi] warning: model catalog unavailable: {error}", file=sys.stderr)
        return set()

    catalog = set()
    for line in result.stdout.splitlines()[1:]:
        parts = line.split()
        if len(parts) >= 2:
            catalog.add(f"{parts[0]}/{parts[1]}")
    return catalog


def apply_policies(settings: dict[str, Any], host: dict[str, Any]) -> None:
    """Drop removed and host-excluded packages."""
    excluded = set(host.get("excludePackages", [])) | REMOVED_PACKAGES
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


def apply_policy(settings: dict[str, Any], policy: dict[str, Any], host: dict[str, Any]) -> list[str]:
    apply_policies(settings, host)
    enabled: list[str] = []
    seen: set[str] = set()
    for group_name in host["groups"]:
        for model in policy["groups"].get(group_name, []):
            if model not in seen:
                seen.add(model)
                enabled.append(model)

    catalog = available_models()
    if catalog:
        missing = [model for model in enabled if model not in catalog]
        if missing:
            print(f"[pi] dropping models absent from the catalog: {missing}")
            enabled = [model for model in enabled if model in catalog]

    fallback_provider, fallback_model = policy["defaults"]["fallbackModel"].split("/", 1)
    settings["enabledModels"] = enabled
    if host.get("theme"):
        settings["theme"] = host["theme"]
    settings["defaultProvider"] = host.get("defaultProvider") or fallback_provider
    settings["defaultModel"] = host.get("defaultModel") or fallback_model
    settings["defaultThinkingLevel"] = host.get("defaultThinkingLevel") or policy["defaults"]["thinking"]
    return enabled


def main() -> int:
    if len(sys.argv) != 5:
        print("usage: settings.py BASE POLICY SETTINGS HOST", file=sys.stderr)
        return 2

    base_path, policy_path, settings_path, host_path = map(Path, sys.argv[1:])
    base = read_json(base_path, {})
    policy = read_json(policy_path, {})
    settings = merge_settings(base, read_json(settings_path, {}))

    if policy:
        slug, host = resolve_host(policy, host_path)
        enabled = apply_policy(settings, policy, host)
        print(
            f"[pi] host={slug} models={len(enabled)} "
            f"default={settings['defaultProvider']}/{settings['defaultModel']}"
        )
    else:
        print(f"[pi] warning: model policy missing: {policy_path}", file=sys.stderr)
        apply_policies(settings, {})

    write_json(settings_path, settings)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

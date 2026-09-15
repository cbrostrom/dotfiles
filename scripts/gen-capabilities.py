#!/usr/bin/env python3
"""Generate the capability map (~/.agents/capabilities.md).

Scans three sources of truth and writes one compact manifest agents can route
through on demand (never part of the always-loaded system prompt, so prompt
caching is unaffected):

  1. Paseo plugins  — ~/Projects/personal/paseo-plugins/*/  (paseo-plugin.json + README)
  2. Pi extensions  — ~/.pi/agent/extensions/*/index.ts (first doc comment) + root *.ts
  3. Shared skills  — ~/.agents/skills/*/SKILL.md (frontmatter description)

Run from setup/paseo.sh and setup/pi.sh. The manifest is a
build artifact: staleness is fixed by regenerating, never by hand-editing.
"""

from __future__ import annotations

import json
import re
from datetime import datetime
from pathlib import Path

HOME = Path.home()
PLUGINS_DIR = HOME / "Projects/personal/paseo-plugins"
EXTENSIONS_DIR = HOME / ".pi/agent/extensions"
SKILLS_DIR = HOME / ".agents/skills"
OUT_FILE = HOME / ".agents/capabilities.md"

VERIFY_PATHS = [
    str(PLUGINS_DIR / "paseo-steps-viewer"),
    str(EXTENSIONS_DIR / "file-search"),
    str(SKILLS_DIR / "higgins"),
]


def first_doc_comment(path: Path) -> str:
    """Leading doc comment: first /** ... */ block near the file top, else leading // lines."""
    try:
        text = path.read_text()[:2000]
    except OSError:
        return ""
    match = re.match(r"\s*/\*\*(.*?)\*/", text, re.DOTALL)
    if match:
        for line in match.group(1).splitlines():
            line = re.sub(r"^\s*\*\s?", "", line).strip()
            if line:
                return line
    slash_lines = []
    for line in text.splitlines():
        stripped = line.strip()
        if stripped.startswith("//"):
            slash_lines.append(stripped.lstrip("/").strip())
        elif stripped:
            break
    return slash_lines[0] if slash_lines else ""


def readme_first_line(path: Path) -> str:
    try:
        for line in path.read_text().splitlines():
            line = line.strip()
            if line and not line.startswith("#"):
                return line
    except OSError as error:
        print(f"warning: cannot read {path}: {error}", file=sys.stderr)
    return ""


def clean(text: str, width: int = 110) -> str:
    text = re.sub(r"\s+", " ", text).strip()
    return text[: width - 1] + "…" if len(text) > width else text


def paseo_plugins() -> list[str]:
    rows = []
    for plugin_dir in sorted(PLUGINS_DIR.iterdir()) if PLUGINS_DIR.is_dir() else []:
        manifest = plugin_dir / "paseo-plugin.json"
        if not manifest.is_file():
            continue
        try:
            plugin_id = json.loads(manifest.read_text()).get("id", plugin_dir.name)
        except (OSError, ValueError):
            plugin_id = plugin_dir.name
        purpose = readme_first_line(plugin_dir / "README.md")
        if not purpose:
            try:
                purpose = json.loads(manifest.read_text()).get("description", "")
            except (OSError, ValueError):
                purpose = ""
        rows.append(f"| `{plugin_id}` | {clean(purpose) or '—'} |")
    return rows


def pi_extensions() -> list[str]:
    rows = []
    if not EXTENSIONS_DIR.is_dir():
        return rows
    for entry in sorted(EXTENSIONS_DIR.iterdir()):
        name = entry.name
        if name.startswith(".") or name.endswith(".disabled") or name == "notify.json":
            continue
        if entry.is_file() and entry.suffix == ".ts":
            rows.append(f"| `{name}` | {clean(first_doc_comment(entry)) or '—'} |")
        elif entry.is_dir():
            if not list(entry.glob("*.ts")) and not list(entry.glob("*/index.ts")):
                continue  # config-only dir for an npm-installed extension, not code
            index = entry / "index.ts"
            purpose = first_doc_comment(index) if index.is_file() else ""
            rows.append(f"| `{name}/` | {clean(purpose) or '—'} |")
    return rows


def skill_description(skill_md: Path) -> str:
    """description field from SKILL.md frontmatter (single or multi-line)."""
    try:
        head = skill_md.read_text()[:3000]
    except OSError:
        return ""
    match = re.search(r"^description:\s*(.*?)(?=^[a-z_-]+:|\Z)", head, re.DOTALL | re.MULTILINE)
    if not match:
        return ""
    return clean(match.group(1), 130)


def skills() -> list[str]:
    rows = []
    for skill_dir in sorted(SKILLS_DIR.iterdir()) if SKILLS_DIR.is_dir() else []:
        skill_md = skill_dir / "SKILL.md"
        if skill_md.is_file():
            rows.append(f"| `{skill_dir.name}` | {skill_description(skill_md) or '—'} |")
    return rows


def main() -> None:
    plugins, extensions, skills_rows = paseo_plugins(), pi_extensions(), skills()
    verify = " ".join(VERIFY_PATHS)
    lines = [
        "# Capability map",
        "",
        f"_Generated {datetime.now().strftime('%Y-%m-%d %H:%M')} by `~/dotfiles/scripts/gen-capabilities.py` — do not edit by hand. Rerun the script instead._",
        "",
        f"**Safety net:** all of these must exist — `{verify}`. If any is missing the manifest is stale: rerun the generator.",
        "",
        "## Paseo plugins",
        "",
        "Source: `~/Projects/personal/paseo-plugins` (dev clone) → deployed via `~/dotfiles/setup/paseo.sh` → `~/dotfiles/sources/paseo/plugins`. UI-only plugins need no agent action; `paseo-steps-viewer` exposes MCP tools (`list_capabilities`, `save_steps`, `update_steps`, `list_steps`).",
        "",
        "| id | purpose |",
        "|----|---------|",
        *plugins,
        "",
        "## Pi extensions (`~/.pi/agent/extensions`)",
        "",
        "Enforcement/UI extensions need no agent action. `file-search` provides the `fd`/`rg` tools.",
        "",
        "| entry | purpose |",
        "|-------|---------|",
        *extensions,
        "",
        "## Shared skills (`/skill:<name>`)",
        "",
        "| name | description |",
        "|------|-------------|",
        *skills_rows,
        "",
    ]
    OUT_FILE.write_text("\n".join(lines))
    print(f"wrote {OUT_FILE} ({OUT_FILE.stat().st_size} bytes, {len(plugins)} plugins, {len(extensions)} extensions, {len(skills_rows)} skills)")


if __name__ == "__main__":
    main()

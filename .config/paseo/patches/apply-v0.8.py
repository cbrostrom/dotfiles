#!/usr/bin/env python3
"""Apply Paseo 0.8 SDK import fixes to vendored plugins."""

from __future__ import annotations

import json
import re
import shutil
import sys
from pathlib import Path

CLIENT_ROOT_IMPORTS = {
    "PluginClientContext",
    "PluginAgentCommandContext",
    "PluginAgentPanelProps",
    "PluginWorkspacePanelProps",
    "PluginTimelineItemProps",
    "PluginSurfaceProps",
    "PluginTheme",
    "PluginHostProps",
    "usePaseo",
    "useAgent",
    "useRpc",
}

SERVER_ROOT_IMPORTS = {"PluginServerContext", "PluginHandlerContext"}

SHARED_ROOT_IMPORTS = {
    "defineRpc",
    "defineAttachmentSource",
    "defineSettings",
    "PluginTimelineTransformerContribution",
    "PluginRpcContract",
    "RpcInput",
    "RpcOutput",
}

PASEO_CLIENT_TYPES = """import { usePaseo } from "@getpaseo/plugin/client";

export type PaseoApi = ReturnType<typeof usePaseo>;
export type PaseoAgentHandle = ReturnType<NonNullable<PaseoApi>["agents"]["ref"]>;
export type PaseoAgent = Awaited<ReturnType<NonNullable<PaseoApi>["agents"]["get"]>>;
export type PaseoAgentUpdate = Parameters<
  NonNullable<PaseoApi>["agents"]["subscribe"]
>[1] extends (update: infer U) => void
  ? U
  : never;
export type PaseoAgentSendOptions = Parameters<
  ReturnType<NonNullable<PaseoApi>["agents"]["ref"]>["send"]
>[1];
"""

TIMELINE_TYPES = """/** Minimal timeline stubs — @getpaseo/protocol is not importable in plugin bundles. */
export type AgentTimelineItem = {
  type: string;
  detail?: Record<string, unknown>;
  [key: string]: unknown;
};

export type ToolCallTimelineItem = AgentTimelineItem & {
  type: "tool_call";
  status: string;
  detail: { type: string; [key: string]: unknown };
};

export type AgentTaskItem = AgentTimelineItem & {
  type: "task";
  [key: string]: unknown;
};

export type AgentUsage = Record<string, unknown>;
"""

SUBAGENT_AGENT_RECORD = """export interface AgentRecord {
  id: string;
  title?: string | null;
  labels?: Record<string, string> | null;
  archivedAt?: string | null;
  updatedAt: string;
  lastUserMessageAt?: string | null;
}
"""


VALUE_CLIENT_IMPORTS = {"usePaseo", "useAgent", "useRpc"}


def split_import_names(raw: str) -> list[tuple[str, bool]]:
    names: list[tuple[str, bool]] = []
    for part in re.split(r",\s*", raw.strip()):
        part = part.strip()
        if not part:
            continue
        if part.startswith("type "):
            names.append((part.removeprefix("type ").strip(), True))
        else:
            names.append((part, False))
    return names


def render_import(names: list[tuple[str, bool]], module: str) -> str:
    rendered = ", ".join(name if not is_type else f"type {name}" for name, is_type in names)
    has_value = any(not is_type for _, is_type in names)
    keyword = "import" if has_value else "import type"
    return f'{keyword} {{ {rendered} }} from "{module}";'


def route_module(name: str) -> str:
    if name in SERVER_ROOT_IMPORTS:
        return "@getpaseo/plugin/server"
    if name in SHARED_ROOT_IMPORTS:
        return "@getpaseo/plugin"
    if name in CLIENT_ROOT_IMPORTS or name.startswith("Plugin"):
        return "@getpaseo/plugin/client"
    if name in VALUE_CLIENT_IMPORTS:
        return "@getpaseo/plugin/client"
    return "@getpaseo/plugin"


def import_path(from_file: Path, to_module: Path, plugin_root: Path) -> str:
    """Relative import path (no extension) from one plugin file to another."""
    import os

    to_rel = to_module.relative_to(plugin_root).with_suffix("")
    from_rel = from_file.parent.relative_to(plugin_root)
    rel = os.path.relpath(to_rel, from_rel)
    if not rel.startswith("."):
        rel = f"./{rel}"
    return rel.replace("\\", "/")


def rewrite_moved_imports(plugin_dir: Path, moves: list[tuple[Path, Path]]) -> None:
    """Fix ./foo.client imports after files move into client/server/shared/."""
    for path in plugin_dir.rglob("*"):
        if path.suffix not in {".ts", ".tsx"} or "node_modules" in path.parts:
            continue
        text = path.read_text()
        updated = text
        for src, dest in moves:
            token = src.stem
            target = import_path(path, dest, plugin_dir)
            for quote in ('"', "'"):
                updated = updated.replace(f"from {quote}./{token}{quote}", f"from {quote}{target}{quote}")
        if updated != text:
            path.write_text(updated)


def migrate_07_layout(plugin_dir: Path) -> None:
    """Move 0.7 suffix files into client/server/shared and split index.ts."""
    if (plugin_dir / "index.client.tsx").exists() or (plugin_dir / "index.client.ts").exists():
        return

    index_ts = plugin_dir / "index.ts"
    if not index_ts.exists():
        return

    moves: list[tuple[Path, Path]] = []
    for path in list(plugin_dir.iterdir()):
        if not path.is_file():
            continue
        match = re.match(r"^(.+)\.(client|server|shared)\.(ts|tsx)$", path.name)
        if not match:
            continue
        base, runtime, ext = match.group(1), match.group(2), match.group(3)
        dest = plugin_dir / runtime / f"{base}.{ext}"
        dest.parent.mkdir(parents=True, exist_ok=True)
        moves.append((path, dest))

    for src, dest in moves:
        shutil.move(str(src), str(dest))

    rewrite_moved_imports(plugin_dir, moves)

    content = index_ts.read_text()
    handles = re.findall(r"^\s*plugin\.handle\(([^)]+)\);?\s*$", content, re.MULTILINE)
    client_calls = re.findall(
        r"^\s*(plugin\.add\w+\([\s\S]*?\));?\s*$", content, re.MULTILINE
    )

    def remap_import(from_name: str) -> str:
        for src, dest in moves:
            if src.stem == from_name.removeprefix("./"):
                return import_path(plugin_dir / from_name, dest, plugin_dir)
        return from_name

    if handles:
        server_lines = [
            'import type { PluginServerContext } from "@getpaseo/plugin/server";',
        ]
        for line in content.splitlines():
            if m := re.match(r'import \{ (\w+) \} from "(\./[^"]+)";', line):
                name, path = m.group(1), m.group(2)
                if name in {"readUsage", "listUsage"}:
                    token = Path(path).name
                    for src, _ in moves:
                        if src.stem == token or src.stem == Path(path).stem:
                            token = src.stem
                            break
                    for src, dest in moves:
                        if src.stem == token:
                            path = import_path(plugin_dir / "index.server.ts", dest, plugin_dir)
                            break
                    server_lines.append(f'import {{ {name} }} from "{path}";')
        server_lines.append("")
        server_lines.append("export default function contribute(server: PluginServerContext) {")
        for handle in handles:
            server_lines.append(f"  server.handle({handle});")
        server_lines.append("  return () => {};")
        server_lines.append("}")
        (plugin_dir / "index.server.ts").write_text("\n".join(server_lines) + "\n")

    if re.search(r"\bplugin\.add", content):
        client_lines = [
            'import type { PluginClientContext } from "@getpaseo/plugin/client";',
        ]
        for line in content.splitlines():
            if m := re.match(r'import \{ (\w+) \} from "(\./[^"]+)";', line):
                name, path = m.group(1), m.group(2)
                if name.endswith("Surface") or "client" in path:
                    for src, dest in moves:
                        if path.endswith(src.name) or Path(path).stem == src.stem:
                            path = import_path(plugin_dir / "index.client.tsx", dest, plugin_dir)
                            break
                    client_lines.append(f'import {{ {name} }} from "{path}";')
        for line in content.splitlines():
            if re.match(r"^const ", line):
                client_lines.append(line)
        client_lines.append("")
        client_lines.append("export default function contribute(client: PluginClientContext) {")
        func = re.search(
            r"export default function contribute\(plugin: PluginContext\) \{(.*)\}\s*$",
            content,
            re.DOTALL,
        )
        if func:
            body = func.group(1)
            body = re.sub(r"^\s*plugin\.handle\([^)]+\);?\s*$", "", body, flags=re.MULTILINE)
            body = re.sub(r"\bplugin\.", "client.", body)
            client_lines.append(body.rstrip())
        else:
            for call in client_calls:
                client_lines.append("  " + call.replace("plugin.", "client."))
            client_lines.append("  return () => {};")
        if "return () => {}" not in client_lines[-1]:
            if not client_lines[-1].strip().startswith("return"):
                client_lines.append("  return () => {};")
        client_lines.append("}")
        (plugin_dir / "index.client.tsx").write_text("\n".join(client_lines) + "\n")

    index_ts.unlink()


def rewrite_imports(content: str, rel_depth: int) -> str:
    content = content.replace(
        "@getpaseo/plugin/react-native",
        "@getpaseo/plugin/client/react-native",
    )

    import_re = re.compile(
        r'import\s+(type\s+)?\{([^}]+)\}\s+from\s+"@getpaseo/plugin";',
        re.MULTILINE,
    )

    for match in list(import_re.finditer(content)):
        force_type = bool(match.group(1))
        names = split_import_names(match.group(2))
        if force_type:
            names = [(name, True) for name, _ in names]

        grouped: dict[str, list[tuple[str, bool]]] = {}
        for name, is_type in names:
            module = route_module(name)
            grouped.setdefault(module, []).append((name, is_type))

        replacement_parts = [
            render_import(grouped[module], module) for module in sorted(grouped)
        ]
        content = content.replace(match.group(0), "\n".join(replacement_parts), 1)

    if rel_depth == 0:
        client_types_rel = "./client/paseo-client-types"
    else:
        client_types_rel = "../" * rel_depth + "client/paseo-client-types"
    content = re.sub(
        r'import type \{([^}]*)\} from "@getpaseo/client";',
        lambda m: f'import type {{{m.group(1)}}} from "{client_types_rel}";',
        content,
    )
    content = content.replace('import type { defineRpc }', "import { defineRpc }")
    content = content.replace(
        'import { defineRpc } from "@getpaseo/plugin/server";',
        'import { defineRpc } from "@getpaseo/plugin";',
    )

    return content


def patch_plugin(plugin_dir: Path) -> None:
    migrate_07_layout(plugin_dir)

    manifest = plugin_dir / "paseo-plugin.json"
    data = json.loads(manifest.read_text()) if manifest.exists() else {"id": plugin_dir.name}
    data["requirements"] = {"paseo": ">=0.8.0"}
    manifest.write_text(json.dumps(data, indent=2) + "\n")

    shim = plugin_dir / "shared" / "paseo-v0.8.d.ts"
    if shim.exists():
        shim.unlink()

    needs_client_types = False
    for path in plugin_dir.rglob("*"):
        if path.suffix not in {".ts", ".tsx"}:
            continue
        if "node_modules" in path.parts or path.name.endswith(".test.ts"):
            continue
        original = path.read_text()
        if "@getpaseo/client" in original:
            needs_client_types = True
        rel_depth = len(path.relative_to(plugin_dir).parts) - 1
        updated = rewrite_imports(original, rel_depth)
        if updated != original:
            path.write_text(updated)

    shared_subagent = plugin_dir / "shared" / "subagent-activity.ts"
    if shared_subagent.exists():
        text = shared_subagent.read_text()
        text = re.sub(
            r'import type \{ PaseoAgent \} from "[^"]+";\n',
            "",
            text,
        )
        text = text.replace(
            "export type AgentRecord = PaseoAgent;",
            SUBAGENT_AGENT_RECORD.strip(),
        )
        shared_subagent.write_text(text)

    client_types = plugin_dir / "client" / "paseo-client-types.ts"
    old_shared_types = plugin_dir / "shared" / "paseo-client-types.ts"
    if old_shared_types.exists():
        old_shared_types.unlink()
    if needs_client_types or client_types.exists():
        client_types.parent.mkdir(parents=True, exist_ok=True)
        client_types.write_text(PASEO_CLIENT_TYPES)

    timeline_types = plugin_dir / "shared" / "timeline-types.ts"
    if any(
        "@getpaseo/protocol/agent-types" in path.read_text()
        for path in plugin_dir.rglob("*")
        if path.suffix in {".ts", ".tsx"} and "node_modules" not in path.parts
    ):
        timeline_types.write_text(TIMELINE_TYPES)

    for path in plugin_dir.rglob("*"):
        if path.suffix not in {".ts", ".tsx"}:
            continue
        if "node_modules" in path.parts:
            continue
        text = path.read_text()
        updated = text.replace(
            "../shared/paseo-client-types",
            "../client/paseo-client-types",
        )
        updated = updated.replace("import type { type ", "import type { ")
        if "@getpaseo/protocol/agent-types" in updated:
            rel = path.relative_to(plugin_dir)
            depth = len(rel.parts) - 1
            timeline_rel = "../" * depth + "shared/timeline-types"
            updated = re.sub(
                r'import type \{([^}]*)\} from "@getpaseo/protocol/agent-types";',
                lambda m: f'import type {{{m.group(1)}}} from "{timeline_rel}";',
                updated,
            )
            updated = re.sub(
                r'import \{\s*([^}]*)\s*\} from "@getpaseo/protocol/agent-types";',
                lambda m: f'import type {{{m.group(1)}}} from "{timeline_rel}";',
                updated,
            )
        if updated != text:
            path.write_text(updated)

    apply_dotfiles_overrides(plugin_dir)


def apply_dotfiles_overrides(plugin_dir: Path) -> None:
    """Dotfiles-specific fixes on top of upstream v0.8 migration."""
    plugin_id = plugin_dir.name
    overrides_root = Path(__file__).resolve().parent.parent / "overrides" / plugin_id
    if overrides_root.is_dir():
        for src in overrides_root.rglob("*"):
            if src.is_file():
                rel = src.relative_to(overrides_root)
                dest = plugin_dir / rel
                dest.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(src, dest)

def main() -> int:
    if len(sys.argv) != 2:
        print(f"usage: {sys.argv[0]} <plugin-dir>", file=sys.stderr)
        return 1
    patch_plugin(Path(sys.argv[1]).resolve())
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

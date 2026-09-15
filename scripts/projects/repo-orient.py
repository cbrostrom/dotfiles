#!/usr/bin/env python3
"""Repo-orient capsule schema and generation (R0-03).

Writes machine-local capsules under ~/.cache/repo-capsules/<stable-repo-id>/.
No artifacts inside client repositories.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import subprocess
import sys
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

GENERATOR_VERSION = "0.1.0"
PLAN_ID = "repo-orientation-mvp"
CACHE_BASE = Path.home() / ".cache" / "repo-capsules"

UNTRACKED_CONFIG_NAMES = {
    "package.json",
    "go.mod",
    "Cargo.toml",
    "pyproject.toml",
    "composer.json",
    "shopify.app.toml",
    "docker-compose.yml",
    "docker-compose.yaml",
}


class RepoOrientError(RuntimeError):
    pass


def run_git(root: Path, *args: str, check: bool = True) -> str:
    proc = subprocess.run(
        ["git", "-C", str(root), *args],
        capture_output=True,
        text=True,
    )
    if check and proc.returncode != 0:
        raise RepoOrientError(proc.stderr.strip() or f"git failed: {args}")
    return proc.stdout.strip()


def git_root(start: Path | None = None) -> Path:
    start = (start or Path.cwd()).resolve()
    proc = subprocess.run(
        ["git", "-C", str(start), "rev-parse", "--show-toplevel"],
        capture_output=True,
        text=True,
    )
    if proc.returncode != 0:
        raise RepoOrientError(f"not a git repository: {start}")
    return Path(proc.stdout.strip()).resolve()


def normalize_remote(url: str) -> str:
    url = url.strip()
    url = re.sub(r"^git@([^:]+):", r"https://\1/", url)
    url = re.sub(r"^ssh://([^@]+@)?", "https://", url)
    url = re.sub(r"\.git$", "", url)
    url = re.sub(r"^https?://", "", url)
    url = url.rstrip("/")
    return url.lower()


def slugify_id(value: str) -> str:
    value = re.sub(r"[^a-zA-Z0-9._-]+", "-", value)
    value = re.sub(r"-+", "-", value).strip("-.")
    return value[:120] or "repo"


def initial_commit(root: Path) -> str:
    try:
        return run_git(root, "rev-list", "--max-parents=0", "HEAD")
    except RepoOrientError:
        return ""


def stable_repo_id(root: Path) -> tuple[str, str]:
    """Return (stable_repo_id, identity_source)."""
    root = root.resolve()
    remote = ""
    try:
        remote = run_git(root, "config", "--get", "remote.origin.url", check=False)
    except RepoOrientError:
        remote = ""
    if remote:
        norm = normalize_remote(remote)
        return slugify_id(f"remote-{norm}"), "remote"
    init = initial_commit(root)
    if init:
        digest = hashlib.sha256(f"{root}|{init}".encode()).hexdigest()[:16]
        return slugify_id(f"path-init-{digest}"), "path-init"
    digest = hashlib.sha256(str(root).encode()).hexdigest()[:16]
    return slugify_id(f"path-{digest}"), "path"


def git_dirs(root: Path) -> tuple[Path, Path]:
    git_dir = Path(run_git(root, "rev-parse", "--git-dir")).resolve()
    common = Path(run_git(root, "rev-parse", "--git-common-dir")).resolve()
    return git_dir, common


def is_linked_worktree(root: Path) -> bool:
    git_dir, common = git_dirs(root)
    if git_dir != common:
        return True
    if (root / ".git").is_file():
        return True
    return False


def file_sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def dirty_tracked(root: Path) -> dict[str, str]:
    dirty: dict[str, str] = {}
    rels: set[str] = set()
    for args in (("diff", "--name-only"), ("diff", "--cached", "--name-only")):
        out = run_git(root, *args, check=False)
        for rel in out.splitlines():
            rel = rel.strip()
            if rel:
                rels.add(rel)
    for rel in sorted(rels):
        abs_path = (root / rel).resolve()
        if abs_path.is_file():
            dirty[rel] = file_sha256(abs_path)
    return dirty


def untracked_config_hashes(root: Path) -> dict[str, str]:
    out = run_git(root, "status", "--porcelain", "-u", check=False)
    found: dict[str, str] = {}
    for line in out.splitlines():
        if not line.startswith("?? "):
            continue
        rel = line[3:].strip()
        name = Path(rel).name
        if name not in UNTRACKED_CONFIG_NAMES:
            continue
        path = root / rel
        if path.is_file():
            found[rel] = file_sha256(path)
    for name in UNTRACKED_CONFIG_NAMES:
        path = root / name
        if path.is_file() and name not in {Path(k).name for k in found}:
            rel = name
            st = run_git(root, "ls-files", "--error-unmatch", rel, check=False)
            if st == "":
                found[rel] = file_sha256(path)
    return found


def detect_stack(root: Path) -> str:
    stacks: list[str] = []
    if (root / "package.json").is_file():
        stacks.append("node")
    if (root / "go.mod").is_file():
        stacks.append("go")
    if (root / "Cargo.toml").is_file():
        stacks.append("rust")
    if (root / "pyproject.toml").is_file() or (root / "requirements.txt").is_file():
        stacks.append("python")
    if (root / "composer.json").is_file():
        stacks.append("php")
    if (root / "shopify.app.toml").is_file():
        stacks.append("shopify-app")
    return ",".join(stacks) if stacks else "unknown"


def top_level_dirs(root: Path, limit: int = 8) -> list[str]:
    names: list[str] = []
    for child in sorted(root.iterdir()):
        if not child.is_dir():
            continue
        if child.name.startswith(".") or child.name in {"node_modules", "vendor", "dist", "build", "target"}:
            continue
        names.append(child.name)
        if len(names) >= limit:
            break
    return names


def load_package_json(root: Path) -> dict[str, Any]:
    path = root / "package.json"
    if not path.is_file():
        return {}
    try:
        data = json.loads(path.read_text())
    except json.JSONDecodeError:
        return {}
    if not isinstance(data, dict):
        return {}
    return data


def detect_package_manager(root: Path) -> str:
    if (root / "pnpm-lock.yaml").is_file():
        return "pnpm"
    if (root / "yarn.lock").is_file():
        return "yarn"
    if (root / "bun.lockb").is_file() or (root / "bun.lock").is_file():
        return "bun"
    if (root / "package-lock.json").is_file():
        return "npm"
    if (root / "Cargo.lock").is_file():
        return "cargo"
    if (root / "go.sum").is_file() or (root / "go.mod").is_file():
        return "go"
    if (root / "poetry.lock").is_file():
        return "poetry"
    if (root / "uv.lock").is_file():
        return "uv"
    if (root / "composer.lock").is_file():
        return "composer"
    return "none"


def entry_points(root: Path) -> list[str]:
    """Deterministic entry-point files; names only, bounded count."""
    found: list[str] = []
    pkg = load_package_json(root)
    if isinstance(pkg.get("main"), str):
        found.append(str(pkg["main"]))
    go_mod = root / "go.mod"
    if go_mod.is_file():
        try:
            out = run_git(root, "ls-files", "*/main.go", "main.go", check=False)
            found.extend(sorted(line for line in out.splitlines() if line.strip())[:5])
        except RepoOrientError:
            pass
    for name in ("src/main.ts", "src/main.tsx", "src/main.js", "src/index.ts", "src/index.js", "main.py", "app.py", "cmd/root.go"):
        if (root / name).is_file():
            found.append(name)
    return sorted(set(found))[:8]


def standard_commands(root: Path) -> list[str]:
    """Bounded standard verify/build commands derived from manifests only."""
    cmds: list[str] = []
    pm = detect_package_manager(root)
    pkg = load_package_json(root)
    scripts = pkg.get("scripts") if isinstance(pkg.get("scripts"), dict) else {}
    runner = {"pnpm": "pnpm", "yarn": "yarn", "bun": "bun", "npm": "npm run"}.get(pm, "")
    if (root / "go.mod").is_file():
        cmds.append("go test ./...")
        cmds.append("go vet ./...")
    if (root / "Cargo.toml").is_file():
        cmds.append("cargo test")
    if scripts:
        for name in ("test", "lint", "typecheck", "build"):
            if name in scripts and runner:
                cmds.append(f"{runner} {name}" if runner != "npm run" else f"npm run {name}")
    elif pm in {"pnpm", "yarn", "bun", "npm"}:
        cmds.append("npm test" if pm == "npm" else f"{pm} test")
    if (root / "pyproject.toml").is_file() or (root / "requirements.txt").is_file():
        cmds.append("python3 -m pytest")
    return cmds[:8]


def go_module_name(root: Path) -> str | None:
    path = root / "go.mod"
    if not path.is_file():
        return None
    for line in path.read_text(errors="replace").splitlines():
        line = line.strip()
        if line.startswith("module "):
            return line.split(None, 1)[1].strip()
    return None


def build_l0(root: Path) -> dict[str, Any]:
    """Deterministic L0 identity capsule. Never reads .env, lockfile bodies, or env values."""
    pkg = load_package_json(root)
    manifests = sorted(
        name for name in (
            "package.json", "go.mod", "go.sum", "Cargo.toml", "pyproject.toml",
            "requirements.txt", "composer.json", "shopify.app.toml",
            "docker-compose.yml", "docker-compose.yaml", "Dockerfile",
        ) if (root / name).is_file()
    )
    l0: dict[str, Any] = {
        "version": 1,
        "level": "L0",
        "stack": detect_stack(root),
        "package_manager": detect_package_manager(root),
        "go_module": go_module_name(root),
        "entry_points": entry_points(root),
        "commands": standard_commands(root),
        "manifests": manifests,
        "top_level_dirs": top_level_dirs(root),
    }
    if l0["go_module"] is None:
        del l0["go_module"]
    return l0


def build_generation(root: Path) -> dict[str, Any]:
    root = root.resolve()
    head = run_git(root, "rev-parse", "HEAD")
    tree = run_git(root, "rev-parse", "HEAD^{tree}")
    git_dir, common = git_dirs(root)
    sid, source = stable_repo_id(root)
    gen = {
        "generator_version": GENERATOR_VERSION,
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "stable_repo_id": sid,
        "identity_source": source,
        "root_path": str(root),
        "head_commit": head,
        "tree_hash": tree,
        "git_dir": str(git_dir),
        "git_common_dir": str(common),
        "is_worktree": is_linked_worktree(root),
        "dirty_tracked": dirty_tracked(root),
        "untracked_configs": untracked_config_hashes(root),
        "codebase_memory_generation": None,
    }
    return gen


def generation_fingerprint(generation: dict[str, Any]) -> str:
    payload = {
        "generator_version": generation.get("generator_version"),
        "head_commit": generation.get("head_commit"),
        "tree_hash": generation.get("tree_hash"),
        "is_worktree": generation.get("is_worktree"),
        "dirty_tracked": generation.get("dirty_tracked"),
        "untracked_configs": generation.get("untracked_configs"),
        "codebase_memory_generation": generation.get("codebase_memory_generation"),
    }
    blob = json.dumps(payload, sort_keys=True, separators=(",", ":"))
    return hashlib.sha256(blob.encode()).hexdigest()


def freshness_status(capsule_dir: Path, root: Path) -> tuple[str, dict[str, Any]]:
    gen_path = capsule_dir / "generation.json"
    if not gen_path.is_file():
        return "MISSING", {}
    stored = json.loads(gen_path.read_text())
    current = build_generation(root)
    if generation_fingerprint(stored) == generation_fingerprint(current):
        return "VERIFIED", current
    return "STALE", current


def assert_cache_outside_repo(capsule_dir: Path, root: Path) -> None:
    root = root.resolve()
    capsule_dir = capsule_dir.resolve()
    try:
        capsule_dir.relative_to(root)
        raise RepoOrientError("capsule path must not live inside repository")
    except ValueError:
        return


def write_capsule(root: Path, force: bool = False) -> Path:
    root = git_root(root)
    sid, _ = stable_repo_id(root)
    capsule_dir = (CACHE_BASE / sid).resolve()
    assert_cache_outside_repo(capsule_dir, root)
    capsule_dir.mkdir(parents=True, exist_ok=True)

    status, generation = freshness_status(capsule_dir, root)
    arch_path = capsule_dir / "architecture.json"
    arch_has_l0 = False
    if arch_path.is_file():
        try:
            arch_has_l0 = "l0" in json.loads(arch_path.read_text())
        except json.JSONDecodeError:
            arch_has_l0 = False
    if status == "VERIFIED" and arch_has_l0 and not force:
        return capsule_dir

    generation = build_generation(root)
    stack = detect_stack(root)
    architecture = {
        "version": 1,
        "stack": stack,
        "top_level_dirs": top_level_dirs(root),
        "shared_identity": sid,
        "l0": build_l0(root),
    }
    routes = {"version": 1, "routes": []}
    manifest = {
        "plan_id": PLAN_ID,
        "task_id": "R0-03",
        "generator_version": GENERATOR_VERSION,
        "stable_repo_id": sid,
        "root_path": str(root),
        "written_at": datetime.now(timezone.utc).isoformat(),
        "freshness_fingerprint": generation_fingerprint(generation),
        "files": ["manifest.json", "generation.json", "architecture.json", "routes.json"],
    }

    (capsule_dir / "generation.json").write_text(json.dumps(generation, indent=2) + "\n")
    (capsule_dir / "architecture.json").write_text(json.dumps(architecture, indent=2) + "\n")
    (capsule_dir / "routes.json").write_text(json.dumps(routes, indent=2) + "\n")
    (capsule_dir / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    return capsule_dir


def cmd_ensure(args: argparse.Namespace) -> int:
    root = git_root(Path(args.path) if args.path else Path.cwd())
    capsule = write_capsule(root, force=args.force)
    status, _ = freshness_status(capsule, root)
    print(json.dumps({"capsule_dir": str(capsule), "freshness": status, "stable_repo_id": stable_repo_id(root)[0]}))
    return 0


def cmd_l0(args: argparse.Namespace) -> int:
    root = git_root(Path(args.path) if args.path else Path.cwd())
    capsule = write_capsule(root, force=args.refresh)
    arch = json.loads((capsule / "architecture.json").read_text())
    print(json.dumps(arch.get("l0", {}), indent=2, sort_keys=True))
    return 0


# ── R0-06: optional codebase-memory graph boost ───────────────────────────────

GRAPH_TIMEOUT_SEC = 20


def cbm_project_name(root: Path) -> str:
    """Mirror codebase-memory's path-derived project naming."""
    return str(root).lstrip("/").replace("/", "-").replace(" ", "-")


def graph_candidates(root: Path, terms: list[str], timeout: int = GRAPH_TIMEOUT_SEC) -> list[dict[str, Any]] | None:
    """Ask codebase-memory for structurally relevant files. None = unavailable/stale.

    Never a hard dependency: every failure path returns None and routing proceeds.
    """
    if not terms:
        return None
    try:
        proc = subprocess.run(
            [
                "mcporter", "call", "codebase-memory-mcp", "search_graph",
                f"project={cbm_project_name(root)}",
                "query=" + " ".join(terms[:6]),
                "limit=8",
            ],
            capture_output=True,
            text=True,
            timeout=timeout,
        )
        if proc.returncode != 0:
            return None
        out = proc.stdout.strip()
        start = out.find("{")
        if start < 0:
            return None
        data = json.loads(out[start:])
    except (subprocess.SubprocessError, json.JSONDecodeError, OSError):
        return None
    results = data.get("results") if isinstance(data, dict) else None
    if not isinstance(results, list):
        return None
    files: list[dict[str, Any]] = []
    for item in results[:8]:
        if not isinstance(item, dict):
            continue
        rel = item.get("file") or item.get("file_path") or item.get("path")
        qn = item.get("qualified_name") or item.get("name") or ""
        if rel:
            files.append({"file": rel, "qualified_name": qn})
    return files or None

# ── R0-05: bounded task routing ────────────────────────────────────────────────

STOPWORDS = {
    "the","a","an","and","or","but","if","then","else","for","to","of","in","on","at","by",
    "with","from","is","are","was","were","be","been","being","do","does","did","how","why",
    "what","when","where","which","this","that","these","those","it","its","as","not","no",
    "can","could","should","would","will","shall","may","might","must","add","fix","update",
    "change","make","set","get","use","using","new","all","any","into","out","up","down",
    "about","after","before","between","over","under","again","very","just","more","most",
    "some","only","also","than","there","their","they","them","we","you","your","our",
}

TOKEN_RE = re.compile(r"[a-zA-Z_][a-zA-Z0-9_-]{2,}")

MAX_ROUTES = 3
MAX_OUTPUT_BUDGET_CHARS = 3200  # ~800 tokens


def task_terms(task: str) -> list[str]:
    tokens = [t.lower() for t in TOKEN_RE.findall(task)]
    return [t for t in tokens if t not in STOPWORDS and len(t) >= 3][:16]


def tracked_files(root: Path) -> list[str]:
    out = run_git(root, "ls-files", check=False)
    return [line for line in out.splitlines() if line.strip()]


ROUTE_EXCLUDE_SEGMENTS = {"dist", "build", "node_modules", "vendor", "target", "coverage", "out", "bin", "obj", "gen", "docs", "_archive", ".cache"}


def route_excluded(rel: str) -> bool:
    segs = [seg.lower() for seg in rel.split("/")[:-1]]
    if any(seg in ROUTE_EXCLUDE_SEGMENTS for seg in segs):
        return True
    stem = rel.split("/")[-1].lower()
    if stem.endswith((".lock", ".min.js", ".min.css", ".sum")) or stem in (".env", ".ds_store"):
        return True
    return False


def score_file(rel: str, terms: list[str]) -> int:
    if route_excluded(rel):
        return 0
    rel_lower = rel.lower()
    segments = [seg.lower() for seg in rel.split("/") if seg]
    stem = segments[-1].rsplit(".", 1)[0] if segments else ""
    score = 0
    for term in terms:
        if term == stem:
            score += 10
        elif term in stem:
            score += 6
        for seg in segments[:-1]:
            if term == seg:
                score += 3
            elif term in seg:
                score += 1
        if term in rel_lower:
            score += 1
    # small preference for test files and package roots when terms match anywhere
    if score > 0 and ("test" in stem or "spec" in stem):
        score += 2
    return score


def route_reason(rel: str, terms: list[str]) -> str:
    stem = rel.split("/")[-1].rsplit(".", 1)[0].lower()
    matched = [t for t in terms if t == stem or t in stem or t in rel.lower()]
    if not matched:
        return "top-ranked match for task terms"
    return f"matches task terms: {', '.join(matched[:3])}"


def verification_commands(root: Path) -> list[str]:
    l0 = build_l0(root)
    cmds = list(l0.get("commands", []))
    return cmds[:4]


def route_task(root: Path, task: str, graph: list[dict[str, Any]] | None = None) -> dict[str, Any]:
    terms = task_terms(task)
    files = tracked_files(root)
    scored = [(score_file(rel, terms), rel) for rel in files]
    if graph:
        graph_files = {g["file"]: g for g in graph if g.get("file")}
        scored = [
            (s + 5 if rel in graph_files else s, rel)
            for s, rel in scored
        ]
    positive = [(s, rel) for s, rel in scored if s > 0]
    positive.sort(key=lambda x: (-x[0], x[1]))
    picked = positive[:MAX_ROUTES]
    if not picked:
        # deterministic fallback: entry points first, then top-level files
        fallback = []
        for rel in files:
            if route_excluded(rel):
                continue
            stem = rel.split("/")[-1].lower()
            if stem.startswith("main.") or stem.startswith("index.") or stem == "root.go" or rel in ("readme.md", "go.mod", "package.json"):
                fallback.append(rel)
        picked = [(1, rel) for rel in fallback[:MAX_ROUTES]]
    routes = []
    for score, rel in picked:
        path = root / rel
        if not path.is_file():
            continue
        routes.append({"path": rel, "reason": route_reason(rel, terms), "score": score})
    skip = []
    top_dirs = [seg for seg in top_level_dirs(root)]
    picked_roots = {rel.split("/")[0] for rel, _ in [(r["path"], 0) for r in routes]}
    for d in top_dirs:
        if d not in picked_roots and len(top_dirs) > 1:
            skip.append(d + "/")
    packet = {
        "version": 1,
        "level": "L1",
        "task": task,
        "repo": root.name,
        "read_next": routes,
        "commands": verification_commands(root),
        "unknowns": [],
        "skip": skip[:6],
    }
    return packet


def cmd_orient(args: argparse.Namespace) -> int:
    root = git_root(Path(args.path) if args.path else Path.cwd())
    capsule = write_capsule(root, force=args.refresh)
    graph = None
    graph_state = "off"
    if args.graph:
        graph = graph_candidates(root, task_terms(args.task))
        graph_state = "used" if graph else "unavailable"
    packet = route_task(root, args.task, graph=graph)
    packet["graph"] = graph_state
    # verify every returned path exists (defense in depth)
    packet["read_next"] = [
        r for r in packet["read_next"] if (root / r["path"]).is_file()
    ]
    output = json.dumps(packet, indent=2, sort_keys=True)
    print(output)
    if len(output) > MAX_OUTPUT_BUDGET_CHARS:
        print(f"warning: output {len(output)} chars exceeds budget {MAX_OUTPUT_BUDGET_CHARS}", file=sys.stderr)
    return 0


def cmd_fingerprint(args: argparse.Namespace) -> int:
    root = git_root(Path(args.path) if args.path else Path.cwd())
    gen = build_generation(root)
    print(json.dumps({"fingerprint": generation_fingerprint(gen), "generation": gen}, indent=2))
    return 0


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="repo-orient")
    sub = parser.add_subparsers(dest="cmd", required=True)

    p_ensure = sub.add_parser("ensure-capsule", help="Write or refresh capsule under ~/.cache/repo-capsules")
    p_ensure.add_argument("--path", help="Repository path (default: cwd)")
    p_ensure.add_argument("--force", action="store_true")
    p_ensure.set_defaults(func=cmd_ensure)

    p_fp = sub.add_parser("fingerprint", help="Print generation fingerprint JSON")
    p_fp.add_argument("--path", help="Repository path (default: cwd)")
    p_fp.set_defaults(func=cmd_fingerprint)

    p_l0 = sub.add_parser("l0", help="Print deterministic L0 identity capsule")
    p_l0.add_argument("--path", help="Repository path (default: cwd)")
    p_l0.add_argument("--refresh", action="store_true", help="Rebuild capsule before printing")
    p_l0.set_defaults(func=cmd_l0)

    p_or = sub.add_parser("orient", help="Bounded task route: ≤3 existing files, reasons, commands, skip list")
    p_or.add_argument("task", help="Natural-language task description")
    p_or.add_argument("--path", help="Repository path (default: cwd)")
    p_or.add_argument("--refresh", action="store_true", help="Rebuild capsule before routing")
    p_or.add_argument("--graph", action="store_true", help="Boost routes with codebase-memory search (optional; clean fallback)")
    p_or.set_defaults(func=cmd_orient)

    args = parser.parse_args(argv)
    try:
        return args.func(args)
    except RepoOrientError as exc:
        print(f"repo-orient: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())

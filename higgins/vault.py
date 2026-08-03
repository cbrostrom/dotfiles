"""higgins.vault — safe vault I/O operations.

All vault writes go through this module so write counting stays consistent.
"""

import shutil
from pathlib import Path
from typing import TYPE_CHECKING, Iterator, Optional

if TYPE_CHECKING:
    from higgins.config import HigginsConfig


_SKIP_DIR_NAMES = {
    "archive", ".index", ".git", "node_modules",
    ".obsidian", ".stversions", "__pycache__", ".cache",
}


# ── Low-level file ops ────────────────────────────────────────────────────────

def safe_write(path: Path, text: str) -> None:
    """Atomic write via tmp → rename. Creates parent dirs."""
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(".tmp")
    tmp.write_text(text, encoding="utf-8")
    tmp.rename(path)


def safe_read(path: Path) -> str:
    """Read file text. Returns empty string if missing."""
    try:
        return path.read_text(encoding="utf-8", errors="replace")
    except FileNotFoundError:
        return ""


def safe_move(src: Path, dst: Path, *, overwrite: bool = False) -> Path:
    """Move src to dst. Raises FileExistsError if dst exists and overwrite=False."""
    if dst.exists() and not overwrite:
        raise FileExistsError(f"Destination exists: {dst}")
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.move(str(src), str(dst))
    return dst


def safe_append(path: Path, text: str) -> None:
    """Append text to a file. Creates file if missing."""
    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path, "a", encoding="utf-8") as f:
        if not text.endswith("\n"):
            text += "\n"
        f.write(text)


# ── File iteration ────────────────────────────────────────────────────────────

def vault_md_files(
    root: Path,
    *,
    skip_dirs: Optional[set[str]] = None,
) -> Iterator[Path]:
    """Yield all .md files under root, skipping noise dirs."""
    skip = skip_dirs if skip_dirs is not None else _SKIP_DIR_NAMES
    for md in sorted(root.rglob("*.md")):
        rel = md.relative_to(root)
        if any(p in skip or p.startswith(".") for p in rel.parts[:-1]):
            continue
        yield md


def tier_files(cfg: "HigginsConfig", tier: str) -> Iterator[Path]:
    """Yield .md files for a specific AI tier."""
    tier_path = cfg.tier_path(tier)
    if not tier_path.exists():
        return
    yield from vault_md_files(tier_path)


def inbox_files(cfg: "HigginsConfig") -> Iterator[Path]:
    """Yield files pending triage in vault.inbox."""
    inbox = cfg.vault.inbox
    if not inbox.exists():
        return
    for f in sorted(inbox.iterdir()):
        if f.is_file() and not f.name.startswith("."):
            yield f


# ── Vault writes with write counting ─────────────────────────────────────────

def vault_write(cfg: "HigginsConfig", path: Path, text: str) -> None:
    """Write to vault and increment the FTS5 write counter."""
    safe_write(path, text)
    _count_write(cfg)


def vault_append(cfg: "HigginsConfig", path: Path, text: str) -> None:
    """Append to a vault file and increment the FTS5 write counter."""
    safe_append(path, text)
    _count_write(cfg)


def vault_move(
    cfg: "HigginsConfig",
    src: Path,
    dst: Path,
    *,
    overwrite: bool = False,
) -> Path:
    """Move a file within the vault and increment the write counter."""
    result = safe_move(src, dst, overwrite=overwrite)
    _count_write(cfg)
    return result


def _count_write(cfg: "HigginsConfig") -> None:
    """Silently increment writes_since_index. Never raises."""
    try:
        from higgins.index import meta_increment_writes
        meta_increment_writes(cfg)
    except Exception:
        pass  # write counting is best-effort — never block a vault write

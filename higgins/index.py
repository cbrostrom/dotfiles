"""higgins.index — FTS5 index management + meta.json adaptive scheduling."""

import json
import re
import sqlite3
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import TYPE_CHECKING, Iterator

if TYPE_CHECKING:
    from higgins.config import HigginsConfig


_SKIP_DIR_NAMES = {
    "archive", ".index", ".git", "node_modules",
    ".obsidian", ".stversions", "__pycache__",
}


# ── meta.json ─────────────────────────────────────────────────────────────────

def meta_read(cfg: "HigginsConfig") -> dict:
    """Read meta.json. Returns empty dict if missing or corrupt."""
    try:
        return json.loads(cfg.index.meta.read_text(encoding="utf-8"))
    except Exception:
        return {}


def meta_write(cfg: "HigginsConfig", data: dict) -> None:
    """Atomic write meta.json."""
    tmp = cfg.index.meta.with_suffix(".tmp")
    tmp.parent.mkdir(parents=True, exist_ok=True)
    tmp.write_text(json.dumps(data, indent=2), encoding="utf-8")
    tmp.rename(cfg.index.meta)


def meta_increment_writes(cfg: "HigginsConfig") -> None:
    """Increment writes_since_index. Safe to call on every vault write."""
    meta = meta_read(cfg)
    meta["writes_since_index"] = meta.get("writes_since_index", 0) + 1
    meta_write(cfg, meta)


# ── Scheduling ────────────────────────────────────────────────────────────────

def should_reindex(cfg: "HigginsConfig") -> tuple[bool, str]:
    """Return (do_reindex, reason). reason is human-readable."""
    if not cfg.index.db.exists():
        return True, "index does not exist"

    meta  = meta_read(cfg)
    writes = meta.get("writes_since_index", 0)
    last   = meta.get("last_indexed")

    if writes >= cfg.index.max_write_lag:
        return True, f"write lag {writes} >= threshold {cfg.index.max_write_lag}"

    if not last:
        return True, "never indexed"

    try:
        last_dt = datetime.fromisoformat(last)
        # Ensure tz-aware comparison
        if last_dt.tzinfo is None:
            last_dt = last_dt.replace(tzinfo=timezone.utc)
        age_h = (datetime.now(timezone.utc) - last_dt).total_seconds() / 3600
        if age_h >= cfg.index.max_age_hours:
            return True, f"age {age_h:.0f}h >= max {cfg.index.max_age_hours}h"
    except ValueError:
        return True, "invalid last_indexed timestamp in meta.json"

    return False, f"up-to-date (writes={writes}, age within limit)"


# ── FTS5 rebuild ──────────────────────────────────────────────────────────────

def _vault_md_files(root: Path) -> Iterator[Path]:
    for md in sorted(root.rglob("*.md")):
        rel = md.relative_to(root)
        if any(p in _SKIP_DIR_NAMES or p.startswith(".") for p in rel.parts[:-1]):
            continue
        yield md


def reindex(cfg: "HigginsConfig", *, verbose: bool = False) -> int:
    """Rebuild FTS5 index over vault.ai. Returns chunk count."""
    t0 = time.monotonic()

    cfg.index.db.parent.mkdir(parents=True, exist_ok=True)
    tmp = cfg.index.db.with_suffix(".tmp")
    if tmp.exists():
        tmp.unlink()

    conn = sqlite3.connect(str(tmp))
    conn.execute("""
        CREATE VIRTUAL TABLE chunks USING fts5(
            path     UNINDEXED,
            heading,
            content,
            tokenize = 'porter ascii'
        )
    """)

    rows: list[tuple[str, str, str]] = []
    for md in _vault_md_files(cfg.vault.ai):
        rel = md.relative_to(cfg.vault.ai)
        try:
            text = md.read_text(errors="replace")
        except Exception:
            continue

        current_heading = ""
        current_lines: list[str] = []

        for line in text.splitlines():
            if re.match(r"^#{1,3}\s", line):
                body = "\n".join(current_lines).strip()
                if body or current_heading:
                    rows.append((str(rel), current_heading, body))
                current_heading = line.lstrip("#").strip()
                current_lines = []
            else:
                current_lines.append(line)

        body = "\n".join(current_lines).strip()
        if body or current_heading:
            rows.append((str(rel), current_heading, body))

    conn.executemany("INSERT INTO chunks VALUES (?, ?, ?)", rows)
    conn.commit()
    conn.close()
    tmp.rename(cfg.index.db)

    elapsed_ms = int((time.monotonic() - t0) * 1000)

    # Update meta
    meta = meta_read(cfg)
    prior_avg = float(meta.get("avg_daily_writes_7d", 0.0))
    meta.update({
        "last_indexed":        datetime.now(timezone.utc).isoformat(),
        "writes_since_index":  0,
        "total_chunks":        len(rows),
        "index_duration_ms":   elapsed_ms,
        "avg_daily_writes_7d": round((prior_avg * 6) / 7, 2),
    })
    meta_write(cfg, meta)

    if verbose:
        print(f"FTS5 index rebuilt: {len(rows)} chunks in {elapsed_ms}ms")

    return len(rows)


# ── Search ────────────────────────────────────────────────────────────────────

def search(
    cfg: "HigginsConfig",
    query: str,
    *,
    tier: str = "",
    limit: int = 15,
) -> list[dict]:
    """FTS5 search over vault.ai. Auto-builds index on first call."""
    if not cfg.index.db.exists():
        reindex(cfg, verbose=True)

    tier_filter = {
        "personal": "AND path LIKE 'personal/%'",
        "projects": "AND path LIKE 'projects/%'",
        "project":  "AND path LIKE 'projects/%'",
        "modules":  "AND path LIKE 'modules/%'",
        "module":   "AND path LIKE 'modules/%'",
        "infra":    "AND path LIKE 'infra/%'",
        "sessions": "AND path LIKE 'sessions/%'",
    }.get(tier, "")

    conn = sqlite3.connect(str(cfg.index.db))
    try:
        rows = conn.execute(f"""
            SELECT path, heading,
                   snippet(chunks, 2, '>>>', '<<<', ' … ', 24) AS snip,
                   rank
            FROM chunks
            WHERE chunks MATCH ?
            {tier_filter}
            ORDER BY rank
            LIMIT ?
        """, (query, limit)).fetchall()
    except sqlite3.OperationalError as e:
        raise RuntimeError(f"Search failed: {e}") from e
    finally:
        conn.close()

    return [
        {"path": p, "heading": h, "snippet": s, "rank": r}
        for p, h, s, r in rows
    ]


def search_format_text(results: list[dict]) -> str:
    """Format results as plain text for CLI / MCP output."""
    if not results:
        return "No results."
    lines: list[str] = []
    for r in results:
        heading = f" › {r['heading']}" if r["heading"] else ""
        lines.append(f"{r['path']}{heading}")
        snip = (r["snippet"] or "").strip()
        if snip:
            lines.append(f"  {snip}")
        lines.append("")
    return "\n".join(lines)

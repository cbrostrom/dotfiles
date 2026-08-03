"""higgins.janitor.orchestrator — runs enabled workers in sequence and logs results."""

import json
import sys
from datetime import datetime, timezone
from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from higgins.config import HigginsConfig


# Workers not yet implemented — stubbed here so orchestrator stays forward-compatible
_STUB_WORKERS = {"promoter", "triager", "reviewer"}


def run_all(cfg: "HigginsConfig", *, verbose: bool = False) -> dict:
    """Run all enabled workers in sequence. Returns summary dict."""
    results = []
    t_start = datetime.now(timezone.utc)

    # ── Indexer ───────────────────────────────────────────────────────────────
    if cfg.janitor.workers.indexer:
        from higgins.janitor.indexer import run as run_indexer
        r = _run_worker(run_indexer, cfg)
        results.append(r)
        if verbose:
            _print_result(r)

    # ── Stub workers (log as pending, not run) ────────────────────────────────
    for name in ("promoter", "triager", "reviewer"):
        if getattr(cfg.janitor.workers, name):
            stub = {"worker": name, "ran": False, "reason": "not yet implemented"}
            results.append(stub)
            if verbose:
                _print_result(stub)

    summary = {
        "ts":         t_start.isoformat(),
        "workers":    results,
        "duration_ms": int(
            (datetime.now(timezone.utc) - t_start).total_seconds() * 1000
        ),
    }

    _log_run(cfg, summary)
    return summary


def last_run(cfg: "HigginsConfig") -> dict | None:
    """Return the most recent run summary from runs.jsonl, or None."""
    runs_log = cfg.janitor.log_dir / "runs.jsonl"
    if not runs_log.exists():
        return None
    try:
        lines = [l for l in runs_log.read_text().splitlines() if l.strip()]
        if lines:
            return json.loads(lines[-1])
    except Exception:
        pass
    return None


# ── Internal helpers ──────────────────────────────────────────────────────────

def _run_worker(fn, cfg: "HigginsConfig") -> dict:
    """Call a worker function, catching exceptions so one bad worker never
    stops the orchestrator."""
    try:
        return fn(cfg)
    except Exception as e:
        name = getattr(fn, "__module__", "unknown").split(".")[-1]
        return {
            "worker": name,
            "ran":    False,
            "error":  str(e),
            "reason": "exception",
        }


def _log_run(cfg: "HigginsConfig", summary: dict) -> None:
    """Append summary to runs.jsonl (one JSON object per line)."""
    try:
        runs_log = cfg.janitor.log_dir / "runs.jsonl"
        runs_log.parent.mkdir(parents=True, exist_ok=True)
        with open(runs_log, "a", encoding="utf-8") as f:
            f.write(json.dumps(summary) + "\n")
    except Exception as e:
        print(f"higgins: warning: could not write run log: {e}", file=sys.stderr)


def _print_result(r: dict) -> None:
    name   = r.get("worker", "?")
    ran    = r.get("ran", False)
    reason = r.get("reason", "")
    error  = r.get("error")

    if error:
        print(f"  [{name}] ERROR — {error}")
    elif ran:
        extra = ""
        if "chunks" in r:
            extra += f", {r['chunks']} chunks"
        if "duration_ms" in r:
            extra += f", {r['duration_ms']}ms"
        print(f"  [{name}] ran — {reason}{extra}")
    else:
        print(f"  [{name}] skipped — {reason}")

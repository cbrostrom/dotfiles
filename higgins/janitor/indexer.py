"""higgins.janitor.indexer — adaptive FTS5 rebuild worker."""

from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from higgins.config import HigginsConfig


def run(cfg: "HigginsConfig") -> dict:
    """Run the Indexer worker.

    Checks should_reindex() and rebuilds if needed.
    Returns a result dict consumed by the orchestrator.
    """
    from higgins.index import should_reindex, reindex
    import time

    do_it, reason = should_reindex(cfg)

    if not do_it:
        return {
            "worker":  "indexer",
            "ran":     False,
            "reason":  reason,
        }

    t0     = time.monotonic()
    chunks = reindex(cfg)
    ms     = int((time.monotonic() - t0) * 1000)

    return {
        "worker":      "indexer",
        "ran":         True,
        "reason":      reason,
        "chunks":      chunks,
        "duration_ms": ms,
    }

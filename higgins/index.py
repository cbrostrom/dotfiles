"""higgins.index — FTS5 index management + meta.json. (Step 2 stub)"""
import json
from pathlib import Path


def meta_read(cfg) -> dict:
    """Read .cache/higgins/meta.json, return empty dict if missing."""
    try:
        return json.loads(cfg.index.meta.read_text())
    except Exception:
        return {}

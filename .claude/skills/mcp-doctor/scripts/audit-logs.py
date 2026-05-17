#!/usr/bin/env python3
"""Aggregate Claude Code MCP log events over a time window.

Output: JSON to stdout. Single responsibility: collect + count.
No judgement, no network.
"""
import os, sys, json, collections, argparse
from datetime import datetime, timezone, timedelta

p = argparse.ArgumentParser()
p.add_argument("--days", type=int, default=7)
p.add_argument("--base", default=os.path.expanduser("~/Library/Caches/claude-cli-nodejs"))
args = p.parse_args()

if not os.path.isdir(args.base):
    json.dump({"error": "no claude-cli-nodejs cache", "window_days": args.days, "mcps": []}, sys.stdout)
    sys.exit(0)

cutoff = datetime.now(timezone.utc) - timedelta(days=args.days)
stats = collections.defaultdict(lambda: {"connects":0,"closes":0,"errors":0,"timeouts":0,"sessions":set()})

for root, dirs, fs in os.walk(args.base):
    if "mcp-logs-" not in root:
        continue
    mcp = root.split("mcp-logs-")[-1]
    for fn in fs:
        if not fn.endswith(".jsonl"):
            continue
        path = os.path.join(root, fn)
        try:
            if datetime.fromtimestamp(os.path.getmtime(path), tz=timezone.utc) < cutoff:
                continue
            with open(path) as fh:
                for line in fh:
                    try:
                        e = json.loads(line)
                    except Exception:
                        continue
                    msg = (e.get("debug") or e.get("error") or "").lower()
                    sid = e.get("sessionId", "")
                    if sid:
                        stats[mcp]["sessions"].add(sid)
                    if "successfully connected" in msg: stats[mcp]["connects"] += 1
                    if "closed" in msg or "disconnect" in msg: stats[mcp]["closes"] += 1
                    if "error" in msg: stats[mcp]["errors"] += 1
                    if "timeout" in msg or "timed out" in msg: stats[mcp]["timeouts"] += 1
        except Exception:
            continue

out = {"window_days": args.days, "mcps": []}
for name, s in stats.items():
    out["mcps"].append({
        "name": name,
        "sessions": len(s["sessions"]),
        "connects": s["connects"],
        "closes": s["closes"],
        "errors": s["errors"],
        "timeouts": s["timeouts"],
    })
out["mcps"].sort(key=lambda m: -(m["errors"] + m["timeouts"] + m["closes"]))
json.dump(out, sys.stdout, indent=2)

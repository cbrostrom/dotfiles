#!/usr/bin/env python3
"""inspect-mcp.py <name> — deep-dive one MCP.
Reads ~/.claude.json for transport, surfaces context + fix hint.
"""
import json, sys, pathlib

if len(sys.argv) < 2:
    print("usage: inspect-mcp.py <mcp-name>", file=sys.stderr)
    sys.exit(2)

name = sys.argv[1]
claude = json.loads(pathlib.Path.home().joinpath(".claude.json").read_text())
cfg = (claude.get("mcpServers") or {}).get(name)
out = {"name": name, "found": bool(cfg)}

if cfg:
    out["transport"] = cfg.get("type", "stdio")
    out["target"] = cfg.get("command", cfg.get("url"))
    out["args"] = cfg.get("args", [])
    out["env_keys"] = sorted((cfg.get("env") or {}).keys())
    t = out["transport"]
    tgt = out["target"] or ""
    args_str = str(out["args"])
    if t == "http":
        out["hint"] = (
            "HTTP MCP: check if server reaps idle sessions. "
            "Inspect container logs for 'session ... timed out' patterns. "
            "Look for SESSION_*TIMEOUT* env var. "
            "See references/fix-playbook.md#http-idle-reaper"
        )
    elif "ssh" in tgt:
        out["hint"] = (
            "SSH stdio MCP: verify ~/.ssh/config has ControlMaster auto + "
            "ServerAliveCountMax 6 + TCPKeepAlive yes for the host. "
            "See references/fix-playbook.md#ssh-no-keepalive"
        )
    elif "bunx" in tgt or "bunx" in args_str or "npx" in args_str:
        out["hint"] = (
            "bunx/npx cold-start: pre-warm package cache or pin version. "
            "See references/fix-playbook.md#cold-start-flaky"
        )
    else:
        out["hint"] = "Inspect transport-specific surfaces manually."
else:
    out["hint"] = (
        f"MCP '{name}' not in ~/.claude.json mcpServers. Likely a cloud "
        f"connector (claude.ai *) — see references/fix-playbook.md#cloud-auth-loop"
    )

json.dump(out, sys.stdout, indent=2)

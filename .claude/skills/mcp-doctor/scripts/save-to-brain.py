#!/usr/bin/env python3
"""save-to-brain.py <topic_key> [body_file]
Emit the engram + graphiti payloads the agent should send to mirror a
finding. Body comes from $2 if present, else stdin.

Why a wrapper script: keeps topic-key convention single-sourced and the
call shape identical across sessions. The agent (Claude Code) makes the
actual MCP calls — this script only prepares the args.
"""
import json, sys, os

if len(sys.argv) < 2:
    print("usage: save-to-brain.py <topic_key> [body_file]", file=sys.stderr)
    sys.exit(2)

topic = sys.argv[1]
if len(sys.argv) >= 3 and os.path.isfile(sys.argv[2]):
    with open(sys.argv[2]) as fh:
        body = fh.read()
else:
    body = sys.stdin.read()

payload = {
    "engram": {
        "tool": "mcp__engram-personal__mem_save",
        "args": {
            "topic_key": topic,
            "summary": body,
            "observation_type": "bug",
        },
    },
    "graphiti": {
        "tool": "mcp__graphiti__add_memory",
        "args": {
            "name": topic.split("/")[-1],
            "episode_body": body,
            "group_id": "claude-code",
            "source": "text",
            "source_description": "mcp-doctor finding",
        },
    },
}

json.dump(payload, sys.stdout, indent=2)

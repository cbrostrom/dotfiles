#!/usr/bin/env python3
"""Read audit JSON from stdin, add a `category` field per MCP.
Pattern rules live in references/fix-playbook.md; this script encodes them.
Single responsibility: pattern-match. No I/O beyond stdin/stdout.
"""
import json, sys

d = json.load(sys.stdin)

def classify(m):
    name = m["name"]
    s, c, cl, e, t = m["sessions"], m["connects"], m["closes"], m["errors"], m["timeouts"]
    is_cloud = name.startswith(("claude-ai-", "claude.ai ", "plugin_atlassian", "plugin-atlassian"))
    if s == 0:
        return "unused"
    # Cloud connectors: name-gated. 0 connects + persistent errors = never-authenticated.
    if is_cloud and c == 0 and e > 0:
        return "cloud-auth-loop"
    # HTTP idle-reaper: more connects than sessions (reconnect churn) and errors
    # exceed session count. Catches dockhand (5k err) + graphiti (500 err).
    if c > s and e > s:
        return "http-idle-reaper"
    # SSH no-keepalive: closes exceed sessions, moderate errors, NOT cloud.
    if not is_cloud and cl > s and e > 0 and e < cl * 2:
        return "ssh-no-keepalive"
    # Cold-start: small surface, errors > sessions.
    if s < 50 and e > s:
        return "cold-start-flaky"
    # Healthy: close ≈ session, no errors.
    if cl <= s * 1.2 and e == 0:
        return "healthy"
    return "uncategorized"

for m in d["mcps"]:
    m["category"] = classify(m)

json.dump(d, sys.stdout, indent=2)

---
name: mcp-doctor
description: >
  Diagnose MCP server flakiness in Claude Code. Aggregates client-side MCP
  logs, classifies dodgy servers by root-cause pattern (HTTP idle-reaper /
  SSH no-keepalive / cloud-auth-loop / cold-start), suggests tier-1 fixes,
  and mirrors findings to brain (Engram + Graphiti). Trigger phrases: "mcp
  flaky", "mcp disconnects", "audit mcp", "diagnose mcp", "/mcp-doctor",
  or whenever the user complains a specific MCP keeps dropping.
group: ops
user-invocable: true
---

# MCP Doctor

Map MCP flakiness → root cause → fix. Composable scripts; SKILL.md orchestrates.

## Pipeline

```
audit-logs.sh  →  classify.sh  →  inspect-mcp.sh  →  save-to-brain.sh
   (collect)      (pattern-match)   (deep-dive)        (mirror)
```

Each stage emits the same JSON envelope. Each is callable standalone.

## When to invoke

- User says: "mcp disconnects", "mcp flaky", "engram keeps dropping", "audit mcp", "diagnose mcp", "/mcp-doctor"
- Session start showed `MCP servers are still connecting` for long
- A specific MCP returned an error mid-session

## Step 1 — audit (always start here)

Run `scripts/audit-logs.py [--days 7]`. Outputs JSON to stdout:

```json
{
  "window_days": 7,
  "mcps": [
    {"name": "mcp-dockhand", "sessions": 193, "connects": 825,
     "closes": 2476, "errors": 5136, "timeouts": 3500}
  ]
}
```

Reads `~/Library/Caches/claude-cli-nodejs/mcp-logs-*/*.jsonl`. Counts events per MCP. No judgment.

## Step 2 — classify

Pipe audit output through `scripts/classify.py`. Adds a `category` field per MCP. Categories live in `references/fix-playbook.md`. Current set:

- `http-idle-reaper` — high errors+closes, low connects per session → server reaps idle sessions
- `ssh-no-keepalive` — moderate closes, hits during Mac sleep/wake
- `cloud-auth-loop` — 0 connects, identical err/timeout counts across siblings → never authenticated
- `cold-start-flaky` — bunx/npx cold cache, fails first call per session
- `healthy` — close count ≤ session count, 0 errors

Classifier is a deterministic awk/jq filter, not AI.

## Step 3 — inspect (per-MCP deep-dive)

For each non-healthy MCP, run `scripts/inspect-mcp.py <name>`. Reads transport from `~/.claude.json`, fetches additional context:

- HTTP MCP → reads its container logs via Dockhand MCP, inspects env
- SSH stdio → reads remote service status via the wrapper script's ssh target
- npm/bunx → checks package install state, npm cache hit/miss

Emits suggested fix referencing `references/fix-playbook.md`.

## Step 4 — save to brain

`scripts/save-to-brain.py <topic_key> <body>` writes:

1. Engram: `mem_save` with `observation_type=bug` and the topic key
2. Graphiti: `add_memory` with `group_id=claude-code` linking MCP-name → bug class → applied fix

The script reads JSON from stdin so steps chain: `audit | classify | save-to-brain.sh bugs/mcp-audit-$(date +%F)`.

## Composable use

| Goal | Invocation |
|---|---|
| Quick health snapshot | `scripts/audit-logs.py \| scripts/classify.py \| jq '.mcps[] \| select(.category!="healthy")'` |
| Just inspect one MCP | `scripts/inspect-mcp.py graphiti` |
| Save existing finding | `echo "<body>" \| scripts/save-to-brain.py bugs/my-finding` |
| Full doctor run | `scripts/audit-logs.py \| scripts/classify.py \| tee /tmp/audit.json` then agent reviews + calls `save-to-brain.py bugs/mcp-audit-$(date +%F) /tmp/audit.json` to prepare brain payload |

## Reference files

- [references/fix-playbook.md](references/fix-playbook.md) — diagnostic pattern → fix mapping. Add new patterns here, no script edits needed.
- [references/known-bugs.md](references/known-bugs.md) — solved cases with memory IDs.

## What this skill does NOT do

- Does not auto-apply fixes (each fix touches different surface — settings, ssh config, container env, plugin enable). Apply manually after review.
- Does not diff settings.local.json (use `modules/claude-settings/doctor.sh` instead).
- Does not start/stop MCP servers (use Dockhand MCP or systemctl directly).

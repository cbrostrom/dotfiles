# Known MCP bugs — solved

Append entries here as fixes land. Each entry links to brain memory IDs so the agent can recall full context.

## 2026-05-17 — mcp-dockhand: 30-min session reaper

- **Symptom**: ~5100 errors / 2500 close events / 193 sessions per 7d, ~13 reconnect cycles per Claude Code session
- **Category**: `http-idle-reaper`
- **Fix**: cbrostrom/mcp-dockhand PR #1 — expose `SESSION_INACTIVITY_TIMEOUT_MS` env (default 4h, was 30m hardcoded)
- **Deploy**: set `SESSION_INACTIVITY_TIMEOUT_MS=14400000` in docker-compose
- **Brain**: Engram id 205 (topic `bugs/mcp-dockhand-session-reaper`), Graphiti episode `mcp-dockhand session reaper bug + fix` (group `claude-code`)
- **Sibling fixes from same audit**:
  - SSH ControlMaster + ServerAliveCountMax 6 for superbro/linuxbro (category: `ssh-no-keepalive`)
  - `deniedMcpServers` for 17 unauthed `claude.ai *` connectors (category: `cloud-auth-loop`)

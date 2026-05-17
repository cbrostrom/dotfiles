# MCP fix playbook

Each pattern below maps a `category` from `classify.sh` to a verified fix.
Add new patterns at the bottom; do not edit the script for new patterns.

## http-idle-reaper

**Signal**: errors + closes far exceed session count; ratio close/sessions > 3.

**Root cause**: HTTP MCP server reaps idle sessions on a short timer (often 30 min). Claude Code's Streamable HTTP transport reuses session IDs across Mac sleep/wake → hits reaped sessions → error logged every reconnect.

**Fix order**:
1. **Inspect container** — find the hardcoded timeout constant (`SESSION_INACTIVITY_TIMEOUT_MS`, `IDLE_TIMEOUT`, or similar).
2. **Expose env var** — patch server to read the constant from process.env with a long default (4h+).
3. **Set env on deployment** — add to docker-compose or systemd unit.
4. **Rebuild + restart** — pull new image, `docker compose up -d --pull always <service>`.

**Reference case**: cbrostrom/mcp-dockhand PR #1 (2026-05-17). 30m → 4h default. Engram id 205, Graphiti episode "mcp-dockhand session reaper bug + fix".

## ssh-no-keepalive

**Signal**: SSH stdio MCP; closes moderate, errors present; correlates with Mac sleep/wake.

**Root cause**: `ssh -G <host>` shows `controlmaster false` and `serveralivecountmax 3`. Default 90s tolerance is shorter than typical Mac sleep windows. Each Claude Code restart spawns a fresh ssh handshake (~1-2s overhead).

**Fix**: Append to `~/.ssh/config` for the host:

```
ControlMaster auto
ControlPath ~/.ssh/cm-%C
ControlPersist 10m
ServerAliveInterval 30
ServerAliveCountMax 6
TCPKeepAlive yes
```

Multiplex reuses one master connection across all MCP spawns; ServerAliveCountMax 6 gives 3-min tolerance to network blips.

**Reference case**: ssh-superbro install script (2026-05-17). dotfiles `scripts/install/ssh-superbro.sh`.

## cloud-auth-loop

**Signal**: 0 connects, identical error+timeout counts across multiple sibling MCPs named `claude.ai *`.

**Root cause**: Cloud connectors pushed by claude.ai web UI or enterprise managed-mcp.json. Never authenticated → discovery loop retries forever.

**Fix**: Add server names to `deniedMcpServers` array in `settings.base.json`. Schema supports it as enterprise denylist that overrides managed scope. Example:

```json
"deniedMcpServers": [
  { "name": "claude.ai Figma" },
  { "name": "claude.ai Notion" }
]
```

Then `bash modules/claude-settings/merge.sh` to regenerate `settings.local.json`.

**Reference case**: settings.base.json (2026-05-17). 17 enterprise-pushed connectors silenced.

## cold-start-flaky

**Signal**: Low session count (<50), errors > sessions, MCP started via `bunx` or `npx -y`.

**Root cause**: bunx/npx fetches the package on first call when cache missed; slow + occasionally fails. Notable: `apple-mcp`.

**Fix options**:
1. **Pin version** — `bunx -y @org/pkg@1.2.3` instead of `@latest`. Keeps cache key stable.
2. **Warm cache** — add a SessionStart hook that runs `bunx -y <pkg> --version` to prime the cache.
3. **Vendor install** — `npm i -g <pkg>`, point MCP command to the absolute path.

**Reference case**: apple-mcp flagged "Flaky (disconnects mid-session)" in mcp-servers.list. Not yet fixed at time of writing.

## healthy

No action. Close count ≈ session count is normal end-of-session teardown.

## unused

`sessions: 0` — MCP registered but not invoked in the audit window. Either it isn't useful (consider removing) or the window is too short.

## How to add a new pattern

1. Add a category branch to `scripts/classify.sh` (one line).
2. Append a section to this file with **Signal / Root cause / Fix / Reference**.
3. Keep classifier deterministic — pattern thresholds, not AI judgement.

---
name: tool-restraint
description: Don't over-equip an agent with tools/MCP servers. More tools = more ways to fail and a higher cognitive load. Use when wiring tools or an agent underperforms.
when_to_use: adding MCP servers, an agent with many tools, "give it access to everything"
---

# Tool Restraint

Loading an agent with many MCP servers "just in case" makes it slower and dumber, not more capable — tool-use agents hit sharp capability cliffs as cognitive load rises.

- Enable **only** the servers the current work actually uses. Remove the rest.
- Prefer official servers for credentialed tools; never install speculatively.
- Each tool's description eats context on every turn — fewer, sharper tools beat a junk drawer.
- Before adding a write-scoped server, add a hook that logs every call.

## MCP via MCPorter (preferred)

Do **not** register every MCP server as native agent tools. Prefer MCP-as-tool-calls:

| Layer | Role |
|---|---|
| `~/.mcporter/mcporter.json` | Canonical server defs (all agents) |
| Pi `mcporter` tool (`pi-mcporter`) | `search` / `describe` / `call` with `defaultExposure: index` |
| Shell `mcporter call server.tool …` | Same path from any agent with a shell |
| Cursor `mcporter serve` | Optional thin bridge; keep `--servers` allowlist small + `lifecycle: keep-alive` |

Exceptions for native/direct tools: high-frequency local brains only (e.g. `higgins`, `deja` with `directTools: true`).

Never put dockhand (300+ tools) or similar mega-servers into Cursor/Pi native exposure.

If the agent picks the wrong tool or thrashes, the fix is usually fewer tools with clearer descriptions, not a smarter model.

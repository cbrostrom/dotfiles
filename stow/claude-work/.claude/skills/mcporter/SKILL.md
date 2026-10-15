---
name: mcporter
description: Use Jira, Confluence or Shopify docs from work servers via the mw wrapper. Use for Jira keys, JQL, Confluence links, atlassian.net URLs, Shopify API questions.
---

# mcporter (work servers via `mw`)

No MCP servers are registered in Claude Code. Work servers run through `mw`, a wrapper around mcporter pinned to the work config. Never call raw `mcporter`.

Servers: `atlassian-agent-akqa`, `atlassian-agent-fiskars`, `shopify-dev-mcp`, `codebase-memory-mcp`.

1. Discover: `mw list` or `mw list <server> --schema`.
2. Check the schema once before the first call to a tool.
3. Call: `mw call <server>.<tool> key=value`.

Atlassian: five read-only tools with capped output. Match the profile to the site: atlassian.net host or issue prefix for AKQA vs Fiskars. See the `atlassian-agent` skill for tool limits.

Server admin (`mw config`, `mw auth`) is manual only.

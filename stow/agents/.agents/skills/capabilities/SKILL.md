---
name: capabilities
description: Route tasks to the right custom tool. Reads the generated capability map (~/.agents/capabilities.md) covering Paseo plugins, pi extensions, and shared skills. Use when a task touches MCP servers, Paseo plugins, step plans, workspace integrations, or when you wonder "is there a tool for X". Also the safety net for stale inventories.
---

# Capability Router

Reads the generated capability map and routes the task to the right tool. The map is a build
artifact of `~/dotfiles/scripts/gen-capabilities.py` — never edit it by hand.

## Workflow

### 1. Read the map

Read `~/.agents/capabilities.md`.

### 2. Safety net — staleness check (do this before trusting any entry)

The manifest header lists three verify paths (one per section). Check they exist:

```bash
ls <verify-path-1> <verify-path-2> <verify-path-3> 2>/dev/null
```

If any is missing, or an entry you need points at a nonexistent file/command:

1. Rerun the generator: `~/dotfiles/scripts/gen-capabilities.py`
2. Re-read the map and route again.

Never route to an entry you could not verify — flag it to the user instead.

### 3. Route

Output exactly:

```
## Capability route

Task: <one-line task summary>

Use:
- <name> — <trigger/why> — <where it lives> — <how to invoke>
```

One to three entries, no padding. If nothing matches, say so — do not force a route.

## Sections

- **Paseo plugins** — mostly UI-only (no agent action). Exception: `paseo-steps-viewer` exposes MCP tools (`save_steps`, `update_steps`, `list_steps`).
- **Pi extensions** — enforcement/UI extensions need no agent action. Exception: `file-search` provides the `fd`/`rg` tools.
- **Shared skills** — invoke with `/skill:<name>`.

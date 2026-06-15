# Memory (Engram + Graphiti) — shared routing rules

Canonical source for both Claude Code and Cursor. Edit only this file. Claude
includes via `@engram-graphiti.md`; Cursor reads from cloud User Rules (paste
content of this file there once, re-paste when this file changes).

**Primary brain: flat-file vault (`~/Vaults/Brain/Brains/<slug>.md`).** Brain hook loads it automatically at session start. Engram = write-only by default; query only on explicit `.recall`. Graphiti = disabled until relational queries are needed at scale.

## Engram — flat memory (key-value + FTS5, fast recall)

Gentleman-Programming Engram (Go binary, SQLite + FTS5). NOT engram.fyi (different product, npm-based, name collision). Local binary at `~/.engram/`, git-synced across machines. No Tailscale required.

Single vault: `engram-personal` — all projects (personal + work).

MCP tool names are prefixed by server name and have `mem_*` action suffix
(e.g. `mcp__engram-personal__mem_save`). Always use `engram-personal` tools.

### When to call which tool

| Action | Tool | When |
|---|---|---|
| Load prior context | `mem_context` | Only on explicit `.recall` or "what did we do last session" — NOT automatic |
| Save a decision/bug/convention/discovery | `mem_save` | Proactively after any of those — do not wait for "remember this" |
| Search across all observations | `mem_search` | Only on explicit `.recall` or when vault grep returns nothing |
| Get full untruncated content | `mem_get_observation(id)` | Only when `mem_search` snippet is insufficient |
| Persist evolving topic | `mem_save` with `topic_key` | Topic that gets updated over time (devices/X, architecture/Y) |
| End-of-session summary | `mem_session_summary` | On `.bye` / `.wrap` only |
| Conflict surfacing | `mem_compare` / `mem_judge` | When a new observation contradicts an existing one |

### Token + speed optimization

- Use `type` filter on `mem_search` when scope is known (decision / architecture / bugfix / config / pattern / discovery / learning)
- Prefer `topic_key` upserts over creating duplicate observations
- Use `mem_context` (~400 tok) instead of broad search when querying

### Local UI / inspection

- `engram tui` — interactive terminal UI for browsing + deleting observations
- `engram stats` — vault totals
- `engram search '<query>'` — CLI search
- `engram doctor` — vault diagnostics
- `engram sync --status` — git sync status

### Vault routing

Always use `engram-personal`. No vault switching needed.

### Device state sync (Claude Code only — irrelevant for Cursor)

At session start, Claude reads
`~/.config/dotfiles/.claude/devices/<hostname>.json` and saves it to
`engram-personal` with `topic_key=devices/<hostname>`. Cursor sessions skip
this — there is no equivalent device-snapshot hook. Do not fail or warn if
the file is absent.

## Graphiti — knowledge graph (temporal, relational)

**Status: disabled / on-demand only.** Graphiti quota errors have been recurring; relational queries are not yet needed at current scale. Skip all automatic Graphiti calls. Re-enable when user explicitly asks for entity relationship queries.

Neo4j-backed temporal graph on SuperBro at HTTP MCP
`http://100.100.1.50:8000/mcp`. Group ID `claude-code` is shared across all
sessions on all tools (Claude, Cursor, future agents).

Use Graphiti for (when re-enabled):

- Relationships between entities (people, projects, services, tools, preferences)
- Facts that change over time — Graphiti tracks when a fact was true and when it expired
- Cross-project knowledge that benefits from graph traversal

### Graphiti tool calls

| Action | Tool |
|---|---|
| Save an episode (text, message, JSON) | `add_memory` |
| Search by entity type / label | `search_nodes` |
| Search by fact / relationship | `search_facts` |
| Read single edge by UUID | `get_entity_edge` |
| List recent episodes | `get_episodes` |

## When to use which (shared decision table)

| Signal | Use |
|---|---|
| Session start | Brain hook loads `Brains/<slug>.md` automatically — no MCP call needed |
| Quick fact, convention, bug fix | Engram `mem_save` only |
| "what did we do last session?" / explicit `.recall` | Engram `mem_context` |
| "what do you know about X?" / explicit `.recall` | Engram `mem_search` then vault grep |
| Relational queries ("how does X relate to Y?") | Graphiti — only when explicitly asked |
| End of session (`.bye` / `.wrap`) | Engram `mem_session_summary` |

## Keyword dispatch (matches both tools)

| Keywords / intent | Action |
|---|---|
| "remember", "save this", "note that", "don't forget" | Engram `mem_save` |
| `.recall`, "what did we do", "last session", "pick up where" | Engram `mem_context` |
| "how does X relate to Y", "connections between", "timeline of" | Graphiti — only on explicit ask |
| "what do you know about X", "recall", "search memory" | Engram `mem_search` then vault grep |
| `.bye` / `.wrap` / "we're done", "wrapping up" | Engram `mem_session_summary` |

## Maintenance

- Edit canonical rules at `~/dotfiles/.shared-rules/engram-graphiti.md`
- After editing, paste content into Cursor cloud User Rules (Settings → Rules)
- Update marker: `touch ~/dotfiles/.shared-rules/.cursor-synced`
- `./scripts/doctor.sh` warns if marker is older than the canonical file

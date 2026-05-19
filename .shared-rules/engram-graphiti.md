# Memory (Engram + Graphiti) — shared routing rules

Canonical source for both Claude Code and Cursor. Edit only this file. Claude
includes via `@engram-graphiti.md`; Cursor reads from cloud User Rules (paste
content of this file there once, re-paste when this file changes).

Two complementary memory systems on SuperBro VPS, both reachable over
Tailscale. Use both proactively in every session — do not wait to be asked.

## Engram — flat memory (key-value + FTS5, fast recall)

Yvgude's Engram (Go binary, SQLite + FTS5). NOT engram.fyi (different
product, npm-based, name collision). Current version on superbro: v1.15.9.

Two vaults, accessed via SSH-stdio MCP from this machine:

- `engram-personal` — all projects (personal + work). Default vault.
- `engram-work` — `stellar-shopify` only. Safe to share with AKQA colleagues.

MCP tool names are prefixed by server name and have `mem_*` action suffix
(e.g. `engram-personal-mem_save`, `engram-work-mem_search`). Rules apply to
whichever vault is active for the current cwd.

### When to call which tool

| Action | Tool | When |
|---|---|---|
| Load prior context at session start | `mem_context` | Always, first action of every session unless explicitly stateless |
| Save a decision/bug/convention/discovery | `mem_save` | Proactively after any of those — do not wait for "remember this" |
| Search across all observations | `mem_search` | Before assuming context, before re-deriving an answer |
| Get full untruncated content | `mem_get_observation(id)` | Only when `mem_search` snippet is insufficient |
| Persist evolving topic | `mem_save` with `topic_key` | Topic that gets updated over time (devices/X, architecture/Y) |
| End-of-session summary | `mem_session_summary` | Before saying "done" or wrapping up |
| Conflict surfacing | `mem_compare` / `mem_judge` | When a new observation contradicts an existing one |

### Vault routing (cwd-based)

- Inside `~/Projects/Shopify/Fiskars/stellar-shopify` → `engram-work` tools
- Anywhere else → `engram-personal` tools

### Token + speed optimization

- Use `type` filter on `mem_search` when scope is known (decision / architecture / bugfix / config / pattern / discovery / learning)
- Prefer `topic_key` upserts over creating duplicate observations
- Use `mem_context` (~400 tok) instead of broad search at session start
- Engram tools have SSH spawn overhead; batch related saves into one call when possible

### Local UI / inspection (no extra infra needed)

- `ssh -t superbro engram tui` — interactive terminal UI for browsing observations
- `ssh superbro engram stats` — totals across vaults
- `ssh superbro engram search '<query>'` — CLI search with same FTS engine
- `ssh superbro engram doctor` — vault diagnostics

### Device state sync (Claude Code only — irrelevant for Cursor)

At session start, Claude reads
`~/.config/dotfiles/.claude/devices/<hostname>.json` and saves it to
`engram-personal` with `topic_key=devices/<hostname>`. Cursor sessions skip
this — there is no equivalent device-snapshot hook. Do not fail or warn if
the file is absent.

## Graphiti — knowledge graph (temporal, relational)

Neo4j-backed temporal graph on SuperBro at HTTP MCP
`http://100.100.1.50:8000/mcp`. Group ID `claude-code` is shared across all
sessions on all tools (Claude, Cursor, future agents).

Use Graphiti for:

- Relationships between entities (people, projects, services, tools, preferences)
- Facts that change over time — Graphiti tracks when a fact was true and when it expired
- Cross-project knowledge that benefits from graph traversal ("what tools does Christian use for X?", "how do these projects relate?")
- Structured data and richer context than Engram's key-value model

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
| Quick fact, convention, bug fix | Engram (`mem_save`) — engram only |
| Entity with relationships to other entities | Graphiti (`add_memory`) — graphiti only |
| Session continuity, "what did we do last time?" | Engram (`mem_context`) |
| "How does X relate to Y?", temporal queries | Graphiti (`search_facts` / `search_nodes`) |
| "What do you know about X?" general recall | Both: Engram `mem_search` + Graphiti `search_nodes` |
| End of session | Engram `mem_session_summary` (+ Graphiti `add_memory` for session highlights when relational) |

**Default = single write.** Dual-write doubles cost; reserve for facts that
genuinely live in both modalities (e.g., "Christian decided to use Loopsy on
superbro" — relational entity link AND flat recall by topic). Pure flat
facts → engram only. Pure relational facts → graphiti only.

## Keyword dispatch (matches both tools)

| Keywords / intent | Action |
|---|---|
| "remember", "save this", "note that", "don't forget" | Engram `mem_save` (+ Graphiti `add_memory` if relational) |
| "what did we do", "last session", "pick up where", "context" | Engram `mem_context` |
| "how does X relate to Y", "connections between", "timeline of", "when did X change" | Graphiti `search_facts` / `search_nodes` |
| "what do you know about X", "recall", "search memory" | Both: Engram `mem_search` + Graphiti `search_nodes` |
| "we're done", "wrapping up", "end of session" | Engram `mem_session_summary` (+ Graphiti `add_memory` when relational) |

## Maintenance

- Edit canonical rules at `~/dotfiles/.shared-rules/engram-graphiti.md`
- After editing, paste content into Cursor cloud User Rules (Settings → Rules)
- Update marker: `touch ~/dotfiles/.shared-rules/.cursor-synced`
- `./scripts/doctor.sh` warns if marker is older than the canonical file

@RTK.md
@agent-style/claude-code.md

# Commit messages
- Never append `Co-Authored-By: Claude` (or any Claude co-author trailer) to commit messages. Personal preference, applies in every repo.

# Push / publish whitelist
- Claude must NOT run `git push`, `gh release create`, `gh pr merge`, `npm publish`, `pnpm publish`, `cargo publish`, or similar publishing commands unless the current working directory is listed in `~/.claude/push-whitelist.txt` (one path per line, supports `~`).
- Customer / client repos (anything under `~/Projects/Clients`, `~/Projects/Shopify`, `~/Projects/Internal`, `~/Work`, etc.) must never be added to the whitelist. If a push is needed there, ask the user to do it manually.
- Enforcement lives in `~/.claude/hooks/git-push-guard.sh` (PreToolUse:Bash). The hook denies by default; treat a denial as the correct outcome and stop — do not retry, force, or work around it.
- To opt a personal repo in: append its path to `~/.claude/push-whitelist.txt`. Mention this to the user before doing it.

# Memory (Engram + Graphiti)

Two complementary memory systems on SuperBro VPS, both accessed via Tailscale MCP. Use both proactively in every session.

## Engram — session memory (key-value, fast recall)

Two vaults accessed via SSH MCP:

- `engram-personal` — all projects (personal + work). Default vault.
- `engram-work` — `stellar-shopify` only. Safe to share with AKQA colleagues.

Rules:
- Call `mem_context` at session start to load prior context.
- Use `mem_save` proactively — decisions, bugs, conventions, discoveries. Do not wait to be asked.
- Use `engram-work` tools when cwd is inside the stellar-shopify project. Use `engram-personal` everywhere else.
- Call `mem_session_summary` before ending a session.
- Prefer `mem_save` over writing to CLAUDE.md files for session-specific facts.

## Graphiti — knowledge graph (temporal, relational)

Temporal knowledge graph on SuperBro (Neo4j + OpenAI embeddings). HTTP MCP at `http://100.100.1.50:8000/mcp`.

Use Graphiti for:
- Relationships between entities (people, projects, services, tools, preferences).
- Facts that change over time (Graphiti tracks when facts were true and when they expired).
- Cross-project knowledge that benefits from graph traversal (e.g., "what tools does Christian use for X?", "how do these projects relate?").
- Structured data and richer context than Engram's key-value model.

Rules:
- Save to Graphiti when information involves entities + relationships (not just flat facts).
- Use `add_memory` tool to ingest episodes (text, messages, JSON).
- Use `search_nodes` and `search_facts` to query the graph before making assumptions.
- Group ID is `claude-code` — shared across all sessions.
- Graphiti complements Engram; save to both when appropriate. Engram for quick recall, Graphiti for relational/temporal depth.

## When to use which

| Signal | Use |
|--------|-----|
| Quick fact, convention, bug fix | Engram (`mem_save`) |
| Entity with relationships to other entities | Graphiti (`add_memory`) |
| Session continuity, "what did we do last time?" | Engram (`mem_context`) |
| "How does X relate to Y?", temporal queries | Graphiti (`search_facts`) |
| Both apply | Save to both |

MCP servers registered via `~/.dotfiles/.claude/mcp-servers.list` — auto-installed on bootstrap.

# Keyword dispatch

Natural language signals that activate specific tools, MCPs, or modes. Match loosely — user won't always use exact words.

## Memory routing

| Keywords / intent | Action |
|---|---|
| "remember", "save this", "note that", "don't forget" | Engram `mem_save` (+ Graphiti `add_memory` if relational) |
| "what did we do", "last session", "pick up where", "context" | Engram `mem_context` |
| "how does X relate to Y", "connections between", "timeline of", "when did X change" | Graphiti `search_facts` / `search_nodes` |
| "what do you know about X", "recall", "search memory" | Both: Engram `mem_search` + Graphiti `search_nodes` |
| "we're done", "wrapping up", "end of session" | Engram `mem_session_summary` (+ Graphiti `add_memory` for session highlights) |

## Infrastructure

| Keywords / intent | Action |
|---|---|
| "containers on superbro", "restart X on superbro", "superbro logs" | `docker-superbro` MCP tools |
| "containers on linuxbro", "linuxbro logs", "plex/sonarr/radarr" | `docker-linuxbro` MCP tools |
| "deploy", "docker compose", "stack" | Appropriate docker MCP based on which host |

## Mode signals

| Keywords / intent | Action |
|---|---|
| "be brief", "save tokens", "less words" | Activate caveman mode if not active |
| "explain in detail", "teach me", "walk me through", "why does" | Drop caveman temporarily, give full explanation |
| "plan this", "architect", "think through", "let's design" | Enter plan mode (`EnterPlanMode`) |
| "review this", "check my code", "audit" | Use review/security-review skill |
| "build UI", "make it look good", "frontend" | Use frontend-design skill |
| "write a post", "draft article", "help me write" | Use writing skill |

## Project detection

| Keywords / intent | Action |
|---|---|
| Shopify, theme, Liquid, sections, blocks | Use shopify-theme-development + liquid-skills |
| stellar-shopify, Fiskars, AKQA | Switch to `engram-work` vault |
| "search Jira", "check Confluence", tickets | Use appropriate atlassian MCP (fiskars vs akqa based on context) |

# graphify
- **graphify** (`~/.claude/skills/graphify/SKILL.md`) - any input to knowledge graph. Trigger: `/graphify`
When the user types `/graphify`, invoke the Skill tool with `skill: "graphify"` before doing anything else.

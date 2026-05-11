@RTK.md
@agent-style/claude-code.md

# Default mode: caveman (full)
Always respond in caveman mode (full intensity) unless user says "stop caveman", "normal mode", or `.normal`. This is the default for every session, every project. No need to activate — it's always on. Drop articles, filler, pleasantries, hedging. Fragments OK. Technical terms exact. Code/commits/security: write normal.

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

Natural language signals that activate specific tools, MCPs, or modes. Match loosely — user won't always use exact words. Dot-commands (`.plan`, `.review`) are shorthand triggers — treat them as immediate mode/skill activation.

## Dot-commands (shorthand triggers)

| Command | Action |
|---|---|
| `.plan` | Auto-route by scope (see "Planning workflow" below). Big work → `planning-with-files:plan` skill. Mid scope → `EnterPlanMode`. Trivial → no plan. |
| `.review` | Invoke review skill |
| `.security` | Invoke security-review skill |
| `.ui` | Invoke frontend-design skill |
| `.write` | Invoke writing skill |
| `.caveman` | Activate caveman mode |
| `.normal` | Deactivate caveman mode |
| `.remember` | Save current context to both Engram + Graphiti |
| `.recall` | Search both Engram + Graphiti for relevant context |
| `.docker` | List containers on contextually relevant host |
| `.stacks` | List stacks via Dockhand MCP (superbro) |

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
| "stacks on superbro", "deploy stack", "superbro stack status" | `mcp-dockhand` MCP (Dockhand API on superbro) |
| "stacks on linuxbro", "linuxbro stack status" | `mcp-dockhand-linuxbro` MCP (Dockhand API on linuxbro) |
| "containers on superbro", "restart X on superbro", "superbro logs" | `mcp-dockhand` or `docker-superbro` |
| "containers on linuxbro", "linuxbro logs", "plex/sonarr/radarr" | `mcp-dockhand-linuxbro` or `docker-linuxbro` |

## Mode signals

| Keywords / intent | Action |
|---|---|
| "be brief", "save tokens", "less words" | Activate caveman mode if not active |
| "explain in detail", "teach me", "walk me through", "why does" | Drop caveman temporarily, give full explanation |
| "plan this", "architect", "think through", "let's design", "spec", "refactor", "redesign" | Auto-pick per threshold heuristics in "Planning workflow" section. Big → `planning-with-files:plan` skill. Mid → `EnterPlanMode`. Plannotator catches the exit either way. |
| "review this", "check my code", "audit" | Use review/security-review skill |
| "build UI", "make it look good", "frontend" | Use frontend-design skill |
| "write a post", "draft article", "help me write" | Use writing skill |

## Project detection

| Keywords / intent | Action |
|---|---|
| Shopify, theme, Liquid, sections, blocks | Use shopify-theme-development + liquid-skills |
| stellar-shopify, Fiskars, AKQA | Switch to `engram-work` vault |
| "search Jira", "check Confluence", tickets | Use appropriate atlassian MCP (fiskars vs akqa based on context) |

# Planning workflow (planning-with-files + plannotator)

Two layers cooperate. Pick author tool by scope; plannotator gates exit automatically.

## Author layer — pick tool by scope

| Signal | Tool | Why |
|---|---|---|
| Trivial scope: ≤ 2 files, single bugfix, one-line change, mechanical rename | No plan. Edit directly. | Planning overhead > work. |
| Mid scope: 2–3 files, well-scoped feature, clear path | `EnterPlanMode` → outline in chat → `ExitPlanMode` | Quick scope, plannotator catches exit. |
| Big scope: ≥ 3 files, new feature, refactor, architecture, spec, multi-step with checkpoints | `planning-with-files:plan` skill (writes `task_plan.md`, `findings.md`, `progress.md` next to work) | Persistent file-based plan; reviewable + resumable across sessions. |

## Threshold heuristics (auto-pick)

Use `planning-with-files:plan` when ANY of:
- Task mentions: architecture, spec, refactor, redesign, migration, multi-step, "approach", "design"
- Files affected ≥ 3 OR new files needed
- Crosses package boundaries (apps/web + apps/api + packages/db)
- DB schema change + API change + frontend change in same task
- User explicitly says: "plan this", "let's design", `.plan`
- Work likely spans multiple sessions

Use `EnterPlanMode` otherwise when scope worth confirming.
Use no plan for obvious single-file fixes.

## Review layer — plannotator (automatic)

Plannotator hooks `ExitPlanMode`. Every plan-mode exit opens a browser UI for visual annotation. User can:
- Approve as-is → implementation proceeds
- Annotate → comments piped back, model revises plan, re-exits → plannotator re-opens with diff

Works regardless of which author tool produced the plan. No manual invocation needed.

## Slash commands (plannotator)

| Command | Purpose |
|---|---|
| `/plannotator-review` | Visual code review on current diff or PR URL |
| `/plannotator-annotate <file.md>` | Annotate any markdown file |
| `/plannotator-last` | Annotate the last assistant message |

# Security model

Tailscale is the primary security layer. All self-hosted MCPs (Engram, Graphiti, mcp-dockhand, docker-linuxbro) are only reachable via Tailscale CGNAT IPs (100.64.0.0/10). A machine must be enrolled in the tailnet to connect. No public exposure, no VPN needed beyond Tailscale.

# graphify
- **graphify** (`~/.claude/skills/graphify/SKILL.md`) - any input to knowledge graph. Trigger: `/graphify`
When the user types `/graphify`, invoke the Skill tool with `skill: "graphify"` before doing anything else.

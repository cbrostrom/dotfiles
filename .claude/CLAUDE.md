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

## Device state sync

At session start, read `~/.config/dotfiles/.claude/devices/<hostname>.json` (hostname = output of `hostname -s`) if it exists. Call `mem_save` (engram-personal) with `topic_key=devices/<hostname>`, summarising the snapshot in plain text (host, os, profile, plugin count + list, mcp list, skills). This keeps Engram as the source-of-truth for Claude config across machines. The JSON file is written by a `SessionStart` hook on every session — just sync it to Engram.

Also save to Engram proactively whenever the user installs/removes plugins, adds MCP servers, or changes skills — don't wait for next session start.

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
| Quick fact, convention, bug fix | Engram (`mem_save`) — **engram only** |
| Entity with relationships to other entities | Graphiti (`add_memory`) — **graphiti only** |
| Session continuity, "what did we do last time?" | Engram (`mem_context`) |
| "How does X relate to Y?", temporal queries | Graphiti (`search_facts`) |
| Both apply | Save to both — **only when fact is BOTH relational AND likely to be recalled flat** |

**Default = single write.** Dual-write doubles cost; reserve for facts that genuinely live in both modalities (e.g., "Christian decided to use Loopsy on superbro" — relational entity link + flat recall by topic). Pure flat facts (conventions, bugs, one-off decisions) → engram only. Pure relational facts (entity X relates to entity Y) → graphiti only.

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
| `.spec` | Invoke `/ck:spec` — write or amend `SPEC.md` (cavekit) |
| `.build` | Invoke `/ck:build` — execute against `SPEC.md`, auto-backprop bugs |
| `.check` | Invoke `/ck:check` — drift report: code vs spec (`§V`, `§I`, `§T`) |
| `.worklog <period>` | Invoke `/worklog` — Apple Calendar → hours/client for hour-registration |

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

## Work-hour registration

| Keywords / intent | Action |
|---|---|
| "give me my work for X", "what did I work on X", "hours for X", "worklog X", "log hours X", "registration for X" | Invoke `/worklog` slash command with `X` as period arg. Pulls Apple Calendar, groups by client (Fiskars / Georg Jensen / NAVI / WPP / AKQA Internal), totals hours, flags unassigned. |

# Planning workflow (planning-with-files + plannotator)

Two layers cooperate. Pick author tool by scope; plannotator gates exit automatically.

## Author layer — pick tool by scope

| Signal | Tool | Why |
|---|---|---|
| Trivial scope: ≤ 2 files, single bugfix, one-line change, mechanical rename | No plan. Edit directly. | Planning overhead > work. |
| Mid scope: 2–3 files, well-scoped feature, clear path | `EnterPlanMode` → outline in chat → `ExitPlanMode` | Quick scope, plannotator catches exit. |
| Big scope: ≥ 3 files, new feature, refactor, architecture, spec, multi-step with checkpoints | `planning-with-files:plan` skill (writes `task_plan.md`, `findings.md`, `progress.md` next to work) | Persistent file-based plan; reviewable + resumable across sessions. |
| Component-level spec w/ invariants and bug history that must survive context resets | `/ck:spec` (cavekit) writes single `SPEC.md` w/ §G/§C/§I/§V/§T/§B sections in caveman encoding | Token-cheap spec format; `/ck:check` provides drift detection; `/ck:build` auto-backprops test failures into §B. |

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

# Cavekit (spec-driven, persistent SPEC.md)

Cavekit complements planning-with-files. Use it for component-level specs where invariants + bug history must survive context resets. Three commands, one `SPEC.md`, caveman-encoded sections.

## Commands

| Command | Purpose |
|---|---|
| `/ck:spec` | Sole mutator. Write/amend `SPEC.md` (sections: §G goal, §C constraints, §I interfaces, §V invariants, §T tasks, §B bugs). |
| `/ck:build` | Read `SPEC.md`, plan, execute. Test failure → auto-backprop into §B + new §V invariant. |
| `/ck:check` | Read-only drift report — flag where code violates §V/§I/§T. |

## When cavekit vs planning-with-files

- planning-with-files = **multi-file project** plan (task_plan.md / findings.md / progress.md split).
- cavekit = **single-component spec** with durable invariants and bug-class memory.
- Both can coexist. Big projects: planning-with-files at root, cavekit `SPEC.md` per component dir.

## Mirror backprop into Engram + Graphiti (MANDATORY)

Whenever `/ck:build` or the `backprop` skill writes a new §B entry or §V invariant to `SPEC.md`:

1. Call `mem_save` on the active Engram vault — topic key `bugs/{component}`, body = the §B entry verbatim + the resulting §V invariant.
2. Call Graphiti `add_memory` — episode body links the bug class to the component node and the commit SHA (if applicable). Group id `claude-code`.

Reason: SPEC.md is per-repo; Engram + Graphiti are cross-session, cross-project. Without the mirror, lessons stay siloed in the repo and don't surface in unrelated work.

## Drift check before commit

Before any `git commit` in a repo containing `SPEC.md`, run `/ck:check`. If drift reported, surface it and ask before staging. Do not commit through unresolved §V violations without explicit user override.

# Read tool routing (override lean-ctx default)

`lean-ctx` MCP says "NEVER use Read" — **ignore that default**. Decide per case:

| Case | Use |
|---|---|
| File <500 LOC, single read | native `Read` |
| File ≥500 LOC, or unknown big size | `ctx_read(mode: signatures)` first; full only if needed |
| Re-reading same file in session | `ctx_read` (cached, ~13 tok per re-read) |
| Searching codebase repeatedly | `ctx_search` |
| One-shot grep | native `Grep` via Bash |
| After `/clear` or session resume | `ctx_session load` |
| Building project map | `ctx_overview` |
| Compressing context near limit | `ctx_compress` |

**Default = native Read/Grep/Bash.** Reach for lean-ctx only when one of the rows above triggers. Small one-shot reads via lean-ctx waste tokens (tool-description overhead > file content).

# Settings architecture (3-layer merge)

`~/.claude/settings.json` symlinks to `dotfiles/.claude/settings.local.json`,
which is **generated** by `modules/claude-settings/merge.sh` from three
tracked layers plus one per-host override:

| Layer | File | Tracked? | Purpose |
|---|---|---|---|
| Base | `settings.base.json` | yes | Shared rules: plugin enablement, language, env, core permissions, memory model, marketplaces |
| Platform | `settings.{darwin,linux,wsl}.json` | yes | OS-specific: hook paths, platform-only MCPs, statusLine |
| Override | `settings.override.json` | gitignored | Per-host manual tweaks. Empty by default |
| Generated | `settings.local.json` | gitignored | Output. **Never hand-edit.** |

Merge precedence: `base → platform → override` (later wins).
Per-key merge strategy lives in `_merge-config.json`
(`concat-dedupe` / `replace-by:command` / `replace-by:matcher+command` /
`deep-merge-by-key` / `shallow-merge`).
Path env-substitution: tracked fragments keep `$VAR` literal; Claude Code
resolves env vars in settings.json at runtime.

## Rules for Claude when editing settings

1. **NEVER edit `settings.local.json` directly.** It is generated. Edits are
   wiped on the next SessionStart.
2. Adding a shared rule (plugin enable/disable, new permission allowlist entry,
   memory rule) → edit `settings.base.json`.
3. Adding a platform-specific rule → edit `settings.{platform}.json`.
4. Adding a per-host one-off → edit that host's `settings.override.json`.
   Never commit.
5. Tracked fragments keep `$VAR` strings literal — DO NOT pre-expand to
   `/Users/...` or `/home/...`. Claude resolves env vars at use time.
6. After editing any tracked layer, run
   `./modules/claude-settings/doctor.sh --fix` or wait for the next
   SessionStart hook.
7. If drift is reported by doctor, decide which layer the drifted value
   belongs in, then `--fix`. Do not paper over it by hand-editing
   `settings.local.json`.
8. Cross-host changes flow `base → platform → override`. Edit, commit, push;
   other hosts pull and regenerate on next session.

When in doubt, `./modules/claude-settings/doctor.sh` first.

# Security model

Tailscale is the primary security layer. All self-hosted MCPs (Engram, Graphiti, mcp-dockhand, docker-linuxbro) are only reachable via Tailscale CGNAT IPs (100.64.0.0/10). A machine must be enrolled in the tailnet to connect. No public exposure, no VPN needed beyond Tailscale.

# graphify
- **graphify** (`~/.claude/skills/graphify/SKILL.md`) - any input to knowledge graph. Trigger: `/graphify`
When the user types `/graphify`, invoke the Skill tool with `skill: "graphify"` before doing anything else.

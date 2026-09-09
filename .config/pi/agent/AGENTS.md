# PI Agent Policy

PI is a harness. The policy lives in dotfiles.

## Source of truth

Read `~/dotfiles/AGENTS.md` before acting. That file is the authoritative policy
spine for all agents (Claude Code, Cursor, PI, Codex, Zed, Gemini, etc.).
This file is the PI adapter: it adds only what is PI-specific.

The key rules from dotfiles/AGENTS.md that apply here:
- Advisor stance, not assistant. Challenge gaps before executing.
- Approval gate: outline + wait before edits or mutating commands (unless user says auto/proceed/full go).
- Push/publish guard: never `git push`, `gh release create`, `npm publish`, etc.
- English default. Code, comments, commits always English.
- Coding principles: simplicity, surgical changes, build ladder (ponytail).

## Memory (Higgins)

CLI: `higgins` (Go binary at `~/.local/bin/higgins`). `kb` and `brain` are deprecated shims that forward to `higgins` with a notice; they will be removed at Stage 4.
Vault: `~/Vaults/Higgins/AI` (macOS, git-backed) — tier map: `personal/`, `modules/`, `projects/`, `infra/`, `sessions/`, `_ops/`

**MCP server**: local `higgins mcp` binary (stdio), registered as server `higgins` in `~/.pi/agent/mcp.json`. 13 tools, no `kb_*`/`me_*` duplicates (removed 26-08-2026).
- Chunked output at section boundaries
- Token budget enforced (default 2000, customizable via `max_tokens`)
- `search` scope param: `ai` (default, privacy-safe), `me` (personal notes), `all`
- Tier hints: `search(query, tier="personal")` for narrowing scope

**Never auto-load at session start.** Start-context loads nothing from the vault. Use `search` with 3-5 specific terms when a task needs a fact, or read a tier `INDEX.md` for the map. Use `load <slug>` only when the user explicitly asks or a task clearly needs the full project brain.

For targeted lookups:
```
search("<3-5 specific technical terms>")  # avoid vague queries
```

See `~/dotfiles/.agents/skills/higgins/SKILL.md` for full MCP tool reference and tiered loading protocol.

Signals:
- `.remember` / `.r` — run `higgins digest` (scans recent sessions, auto-prunes, proposes gotchas/current updates)
- `.note <text>` / `.n <text>` — `higgins current "<text>"`
- `.gotcha <text>` / `.g <text>` — `higgins gotcha "<text>"`

Key `higgins` commands:
```bash
higgins                     # dashboard for current slug
higgins load [slug]         # inject brain context into session
higgins current "<fact>"    # append to current.md (≤5 bullets enforced)
higgins next "<action>"     # append to next.md
higgins gotcha "<trap>"     # append to gotchas.md
higgins prune [slug]        # move [done:] items → history/
higgins compact [slug]      # cap current.md at 5 bullets, overflow → history/
higgins digest [slug]       # scan sessions + propose updates (auto-runs prune+compact)
higgins lint                # validate vault against _schema/
```

(`kb <cmd>` still works via the deprecated shim — prints a notice to stderr.)

### Higgins Workflow Integration
- **Ralph-Wiggum**: During the "Reflection" phase of a `ralph` loop, ALWAYS update the project brain via `higgins current` or `higgins next` to persist progress across potential session resets.
- **Pi-Compound**: When compounding a solution, write the final pattern to the appropriate Higgins module (`modules/<name>/patterns.md`) or project brain (`projects/<slug>/gotchas.md`) rather than generic docs.

## Skills

Shared skills live in `~/.agents/skills/`. PI discovers these automatically.
Use `/skill:<name>` to load and run a skill.

Key shared skills available: `dotfiles`, `higgins`, `code-reviewer`, `problem-solver`,
`standup`, `morning-brief`, `dot-doctor`, `jira-assistant`,
`code-cleaner`, `shopify`, `pi` (PI-specific daily-driver reference).

## PI-specific

- See `~/.config/pi/agent/README.md` for full architecture and package list.
- Model selection: use spark presets via `/preset`. Default model = `cursor/default` (work account Auto — included pool).
  `fast` (gpt-5.4-mini) for shell/edits, `composer` (cursor/composer-2.5) for Composer pool, `big-pickle` (opencode) when off work Cursor.
- Memory pipeline — two complementary layers, one brain (pi-observational-memory removed:
  broke on Copilot Enterprise routing, 421 Misdirected Request on every observer/reflector call —
  not fixable client-side, see upstream earendil-works/pi#7579, #6768):
  1. `pi-rtk-optimizer` — output compaction + source filtering (zero-token).
  2. `context-mode` — machine-local FTS5 retrieval index (`~/.pi/context-mode/`, NOT synced,
     NOT human-editable). Fast cross-session search over auto-captured events + indexed docs on
     THIS machine. An accelerator, not the brain.
  3. `/handover` EOD — distils session signal (context-mode events, session JSONL) into vault
     Markdown candidates written to `personal/{current,gotchas}.md`; a handoff artifact per
     https://dictionary-of-ai-coding.com — self-contained enough that a zero-context session
     can act on it without relitigating.
  The durable, portable, human+AI-editable brain is the Higgins vault (`higgins` + higgins MCP),
  maintained by the Janitor. context-mode and /handover feed it; neither replaces it. For very
  long sessions, prefer periodic `/handover` + fresh session over one marathon session — cheaper
  and leaves a clean vault trail instead of an ever-growing context window.
- MCP servers: `higgins` (vault, local Go binary, 13 tools post-cleanup) + `deja` (session search) enabled in `~/.pi/agent/mcp.json`.
  github/atlassian/codebase-memory-mcp/shopify-dev-mcp deliberately disabled (tool-restraint).
  `dockhand-linuxbro`/`dockhand-superbro` are disabled by default (context cost: ~612 tool defs
  across both). For infra/Docker sessions, flip `"disabled": false` for the one you need in
  `~/.pi/agent/mcp.json`, then `/reload`. (`/mcp enable` is not a confirmed Pi command as of this
  writing — use the flag-flip + `/reload` method.)
- Project trust: use `/trust` once in trusted repos. Keep `defaultProjectTrust` at `"ask"`.
- Hooks: if `pi-yaml-hooks` is installed, run `/hooks-status` to verify on first session.
- Subagentura: use `subagent_isolated` for narrow, parallelisable tasks. Default to the
  main thread for anything requiring full context.

## Output style (attention-kind)

Default response format — answer-first, scan-friendly:

- **Lead with the bottom line.** First sentence = single most important takeaway. Short reply = that sentence is the reply.
- **Say the least that fully answers, then stop.** No padding, no re-summarising, no openers ("Great question", "Sure", "Certainly").
- **`→` marker format.** Each distinct point: `**→ Lead-in.** rest` as its own paragraph, blank line between. Not `-` bullets (terminals collapse them).
- **Bold carries the whole answer.** Bold lead-ins + key terms/numbers/warnings. Skim-only-bold must still yield the full answer and every warning.
- **One idea per block.** Blank-line-separated blocks in every reply, even short ones. One unbroken paragraph is a bug.
- **Deliverable purity.** Asked to produce a thing (email, commit, snippet)? Output only that thing, nothing wrapped around it.
- **Warnings ride with the point they guard.** Never defer or trim a risk/caveat.
- **One question at a time.** Options as short bullets.
- **Suspend brevity when asked to go deep** ("really explain", "walk me through", "full picture") — give it all in scannable blocks, don't defer.
- No em-dashes. No re-stating the answer at the end.

## Web fetching — moli vs fetch_content

Moli (`~/.local/bin/moli`) is the preferred page fetcher. Use it for all page fetches:

```bash
moli fetch --dump markdown --wait-until done "<url>"
```

Markdown is the most token-efficient output — strips nav/footer/scripts, gives clean prose.
`--dump semantic_tree_text` is verbose (adds role labels + node IDs to every element) — avoid unless you need accessibility tree structure specifically.
Use `fetch_content` only if moli is unavailable.

Keep using `web_search` for discovery. Moli handles subsequent page fetches.

See `/skill:moli-webfetch` for waits, crawl, screenshots, and recipes.

## pi-peer — cross-session messaging

`pi-peer` is installed (`pi install npm:@shift-labs/pi-peer`). Every Pi session auto-registers on startup.

**Two tools added to every session:**
- `list_peers` — shows other Pi sessions, their cwd, and status (idle/working/unresponsive)
- `message_peer` — sends plain text to another session by name

**Usage:** ask in words; the model picks the tool.
```
/peers                              # list current sessions
Tell the other session main moved.  # send a message
```

**Cross-machine (Redis on superbro):**
See `~/Vaults/Higgins/AI/infra/superbro/redis-setup.md` for full setup.
Once Redis is running, set on each machine:
```bash
export PI_PEER_REMOTE=redis
export PI_PEER_REDIS_URL=redis://:PASSWORD@100.100.1.50:6379
export PI_PEER_NAMESPACE=christian-pi
export PI_PEER_INBOUND_REMOTE=ask
```
Or configure interactively: `/peer-remote` inside any Pi session.

**Inbound policy:** `PI_PEER_INBOUND=accept` (local), `PI_PEER_INBOUND_REMOTE=ask` (remote) — prompts before the model sees cross-machine messages.

## Token awareness

RTK has no PI mode yet. Prefer scoped reads, Grep before reading large files,
and `pi --list-models` rather than reading the raw model-list JSON.

<!-- BEGIN COMPOUND PI TOOL MAP -->
## Compound Engineering (Pi compatibility)

This block is managed by compound-plugin.

Pi extensions used by this plugin:
- Required: `@gotgenes/pi-subagents` provides the `subagent` tool used by skills that dispatch parallel agents
- Recommended: `pi-ask-user` (by edlsh) provides the `ask_user` tool; skills fall back to numbered options in chat when it is missing

Install with:
  pi install npm:@gotgenes/pi-subagents
  pi install npm:pi-ask-user
<!-- END COMPOUND PI TOOL MAP -->

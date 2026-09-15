---
name: higgins
description: "Vault (Higgins) protocol for all agents. Covers tier map, MCP tool usage (search/load/read/current/next/gotcha/done/save/wrap/pick/path/status/resolve), scope-aware search, on-earn deposit discipline, and INDEX.md navigation. Use when loading context, saving decisions, searching the vault, or at session boundaries. Triggers: load vault, save vault, search vault, .remember, higgins digest."
group: higgins
---

# Higgins — vault protocol

Christian's vault at `~/Vaults/Higgins/AI` (agent-owned knowledge, "AI/") plus `~/Vaults/Higgins/Me` (personal Obsidian notes, "Me/"). Git-backed AI/, Syncthing-only Me/. Single FTS5 index covers both roots. The vault's own contract lives at `$VAULT_AI/AGENTS.md`.

Binary: `~/.local/bin/higgins` (Go, local). MCP server: `higgins mcp` (stdio), registered in `~/.pi/agent/mcp.json` as server name `higgins`. `kb` and `brain` are deprecated CLI shims that forward to `higgins` with a stderr notice — do not rely on them.

## Vault paths

```bash
VAULT_AI=~/Vaults/Higgins/AI   # agent-owned: personal, projects, modules, infra, sessions
VAULT_ME=~/Vaults/Higgins/Me   # personal Obsidian notes (Familie, Hus, Email, etc.)
```

## Tier map (AI/)

```
$VAULT_AI/
  AGENTS.md              # machine contract (read first)
  personal/              # always relevant: current state + gotchas + INDEX.md
  modules/<name>/         # reusable knowledge units; modules/INDEX.md maps them
  projects/<slug>/       # per-project live state
  infra/<host>/          # per-machine state; infra/INDEX.md maps them
  sessions/YYYY/MM/      # auto-captured session extracts
  _ops/                  # curator reports, migration logs
  archive/               # retired projects/modules (local only, not indexed)
```

**Read the tier's `INDEX.md` before searching blind.** `personal/`, `infra/`, and `modules/` each have a short (≤25 line) index — one line per file/host/module, pointers only, no content. Read the map, then fetch the one thing you need. This is cheaper than an unscoped search and cheaper than loading a whole tier.

## MCP tools (13, agent-facing)

Registered on the `higgins` MCP server. Pi shows them as `mcp__higgins_<name>` (e.g. `mcp__higgins_search`) — note there is no double `higgins_higgins_` prefix; the tool names below are bare on purpose.

```
search(query, tier="", scope="ai", max_tokens=2000)
  → FTS5 BM25 search. Ranked hits: path, heading, snippet.
  → scope: "ai" (default — work/project knowledge), "me" (personal notes),
    "all" (both). Personal-life content (Me/) only surfaces when scope is
    explicitly "me" or "all" — this is a deliberate privacy default, not a
    limitation. Don't default to scope:all "just in case."
  → tier hints: tier="personal", tier="projects", tier="modules", tier="infra"
  → Boundary-aware token budget: truncates by dropping whole trailing hits,
    never mid-entry.

load(slug="", full=false, max_tokens=2000)
  → Full context dump: personal + project brain for a slug. Resolves slug
    from cwd if omitted. full=true adds preferences.md + module gotchas.
  → Heavier than search — only call when a task genuinely needs the whole
    brain, not as a session-start reflex (see "Never load at start" below).

read(path, root="me", max_tokens=2000)
  → Read one file by path, relative to root ("me" default, or "ai").
  → Path-confined: "../" escapes are rejected, .md-only. This replaced the
    old unguarded me_read.

status(slug="")            → Dashboard: file sizes, mtimes, chunk count.
resolve()                  → Resolve active slug from cwd/env.
pick(verbose=false)        → List active projects.
path(slug="")              → Print brain directory path for a slug.

current(slug="", text="")  → No text: read current.md. With text: append.
next(slug="", text="")     → No text: read next.md. With text: add item.
gotcha(slug="", text="")   → No text: read gotchas.md. With text: append.
done(slug="", substr)      → Mark first matching next.md item done.
save(slug="", text="")     → Write a history/ snapshot.
wrap(slug="", summary, topic="")  → Save snapshot + optionally set new topic.
```

### What's deliberately NOT on the MCP surface

Ops/maintenance tools (`digest`, `optimise`, `init`, `setup`, `prune`, `compact`, `lint`) are CLI-only — they're janitor/human operations, not agent hot-path, and don't cost a tool definition in every session. Use the CLI (`higgins <cmd>`) for these, not an MCP call.

### Query discipline

- Use 3-5 specific technical terms per query. Vague queries ("dotfiles", "issues") return noise.
- Prefer `search` with a `tier` hint over loading a whole tier when you only need one fact.
- Prefer `read` over `search` when you already know the exact file (e.g. from an INDEX.md).

### Token budgets

- `max_tokens=2000` (default) — safe for most queries.
- `max_tokens=1000` — tight budgets, cross-project work.
- `max_tokens=0` — unlimited. Use sparingly; this is the thing that causes context bloat.

## Never load at session start

**Start-context loads nothing from the vault.** No hook fires `load` automatically. Call `search` with specific terms when a task needs a fact, or read a tier `INDEX.md` for the map. Call `load <slug>` only when the user explicitly asks or a task clearly needs the full project brain — it's ~1,700 tokens of full file contents, not a summary.

## On-earn deposit — when to write, not just when asked

Write a fact the moment it's earned, not at digest time. Four triggers:

- **Traced something non-obvious** (network path, config location, why a service does X) → `gotcha`, immediately.
- **Made a decision with a reason** you'd otherwise re-derive → `current` or a project `decisions.md` line.
- **Corrected a wrong assumption** → overwrite the fact via `current`, don't leave the old one standing.
- **Finished a session with durable state change** → `wrap` with a one-line summary.

This is what makes janitor downtime cosmetic instead of existential — durable facts get written at the moment they're cheap (already in context), not reconstructed later from session logs.

## Save protocol — when to use what

| Situation | Tool/command |
|---|---|
| Discovered a non-obvious trap | `gotcha` — immediately, don't wait |
| New action item | `next` |
| State changed / decision made | `current` |
| Topic shift or chunk completed | `wrap` |
| End of big session, before compaction | CLI `higgins digest` (`.remember` keyword) |

**Do not save:** noise, obvious things, temporary debugging notes, things already in `current.md`.
**Never edit vault files directly.** Only `higgins` (CLI or MCP) writes.

## Full CLI reference (human/terminal use)

```bash
higgins                            # dashboard for active slug
higgins load [slug]                # full context dump
higgins search <query> [--scope ai|me|""] [--tier t] [-n limit]
higgins current "<fact>"           # append to current.md (≤5 bullets hard cap)
higgins next "<action>"            # append to next.md
higgins gotcha "<trap>"            # append to gotchas.md
higgins done <substr>              # mark matching next item done
higgins save "<summary>"           # write history/YYYY-MM-DD-HHMM.md
higgins wrap "<summary>" [topic]   # save snapshot + set new current focus
higgins digest [slug]              # scan sessions, propose updates, auto-prune+compact
higgins prune [slug]               # move [done:] items → history/
higgins compact [slug]             # cap current.md at 5 bullets, overflow → history/
higgins lint                       # validate vault against _schema/
higgins reindex                    # rebuild the FTS5 index (both AI/ and Me/)
higgins status [slug]              # dashboard
higgins path / slug / pick         # utility lookups
```

CLI `search` defaults to searching **both** roots (no privacy default) — that default only applies to the MCP `search` tool, because a human at a terminal already has full vault access. Use `--scope ai`/`--scope me` on the CLI to narrow.

## Security notes (why the tools are shaped this way)

- `read` is path-confined (Clean + prefix check against the resolved root) and `.md`-only. This closed a real path-traversal bug in the old `me_read` (`../../../.ssh/id_rsa` used to resolve outside the vault).
- Every MCP response is passed through central secret redaction (api-key/token/password/bearer patterns, PEM private keys, AWS access key IDs) before it leaves the server. Defense-in-depth, not a guarantee — the real protection is the path confinement above.

## Schema enforcement

`higgins lint` validates:
- `projects/<slug>/`: required files, slug format, ≤5 bullets in current.md, no orphans/stubs
- `modules/<name>/`: `MODULE.md gotchas.md patterns.md decisions.md references.md`
- `personal/`: `current.md preferences.md gotchas.md`
- No flat `.md` at vault root except `AGENTS.md README.md PLAN.md`

## Hard rules

- Never overwrite `current.md` destructively — append or merge only.
- `history/` files are append-only snapshots — never edit after writing.
- No fabricated links — only reference files confirmed to exist.
- Only `higgins` (CLI/MCP) writes to the vault — never direct file edits from agents.

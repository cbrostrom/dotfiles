---
name: kb
description: Knowledgebase (kb) vault protocol for all agents. Covers vault path detection, tier map (personal/modules/projects/infra), load/save protocol via the kb CLI, session capture, and slug resolution. Use when loading session context, saving learnings/decisions, running kb remember/digest, or at session boundaries. Triggered by 'load kb', 'save kb', 'load vault', 'save brain', 'update vault', 'kb context', '.remember', 'kb remember', 'kb digest', or at session boundaries.
group: kb
---

# Knowledgebase (kb) — Patina

Christian's Patina vault at `~/Vaults/Higgins/AI`. Git-backed, plain-markdown, consumed by every agent harness. The vault's own contract lives at `$VAULT_AI/AGENTS.md`.

GitHub: `git@github.com:bybrostrom/patina.git` (private)

## Vault paths

```bash
VAULT_AI=~/Vaults/Higgins/AI                          # macOS (canonical)
VAULT_AI=/mnt/c/Users/christian/Obsidian/AI  # WSL — TBD, confirm on MonsterBro
```

## Tier map

```
$VAULT_AI/
  AGENTS.md              # machine contract (read first)
  personal/              # always loaded: preferences + gotchas + current state
  modules/<name>/        # reusable knowledge units (shareable per-module)
  projects/<slug>/       # per-project live state
  infra/<host>/          # per-machine state (superbro, monsterbro, linuxbro, homelab, cloudcli)
  sessions/YYYY/MM/      # auto-captured TF-IDF summaries (zero-token, never hand-edited)
  tools/kb               # canonical CLI
  tools/session-promote  # zero-token grep → sessions/candidates.md
  _ops/                  # curator reports, migration logs
  archive/               # retired projects/modules
```

## Slug resolution

1. `--tier <t> --slug <s>` args
2. `$KB_SLUG` env
3. `personal` — when cwd is inside `$VAULT_AI`
4. Active plan `repo:` field
5. `git rev-parse --show-toplevel` basename
6. `$PWD` basename

Slug format: `lowercase-kebab` only.

## Full CLI reference

```bash
kb                           # dashboard: active slug, file sizes, history count
kb load [slug]               # 3-tier context dump (personal + module index + project brain)
kb load --full [slug]        # also includes preferences.md + all module gotchas (~4k tokens)
```

## MCP tools (agent-facing, v2+)

kb-mcp exposes these via MCP (auto-discovered by agents):

```
kb_load(slug, full=False, max_tokens=2000)
  → Chunked output, token budget enforced. Default 2000 tokens.
     max_tokens=0 for unlimited.
  → Responses split at section headers (PERSONAL, MODULES, PROJECT)

kb_search(query, tier="", max_tokens=2000)
  → Tier hints: tier:personal, tier:projects, tier:modules, tier:infra
  → Applies token budget (default 2000)

kb_current(slug, text)          → Append to current.md
kb_next(slug, text)             → Append to next.md  
kb_gotcha(slug, text)           → Append to gotchas.md
kb_done(slug, substr)           → Mark item done
kb_save(slug, text)             → Write history snapshot
kb_prune(slug)                  → Move [done:] items
kb_compact(slug)                → Cap current.md at 5 bullets
kb_lint()                       → Validate vault schema
kb_resolve()                    → Get resolved slug for current session
kb_status(slug)                 → Show modified times, file sizes
kb_map(subcommand)              → Project registry, CODEBASE generator

me_list(folder)                 → List personal notes (Me/ vault)
me_read(path)                   → Read personal note
me_search(query, folder)        → Search personal notes
me_folders()                    → Vault structure
me_recent(limit)                → Recently modified notes
```

### Query discipline (MCP v2)
- Use 3-5 specific technical terms per query (e.g., "dotfiles fnm node upgrade")
- Avoid vague queries ("dotfiles", "issues") — triggers broad noise
- Tier hints for cross-project work: `kb_search("tier:personal debug logs")` narrows scope

### Tiered loading protocol (v2)
- **Personal session**: `kb_load("personal")` only (always cached)
- **Project session**: `kb_load("<slug>")` (includes personal internally)
- **Cross-project work**: `kb_load("personal")` only, then targeted `kb_search` queries
- **Infra/deploy**: `kb_load("personal")` + `kb_load("infra/superbro")` when needed

### Token budgets
- `max_tokens=2000` (default) — safe for most queries
- `max_tokens=1000` — tight budgets, cross-project work
- `max_tokens=0` — unlimited (opt-out, use sparingly)

### Chunking behavior
- kb-mcp v2 splits output at `=== SECTION ===` boundaries
- Personal context cached in memory (1hr TTL, auto-invalidates on write)
- Partial chunks truncated at token budget boundary
- See: `~/Vaults/Higgins/AI/plans/kb-mcp-optimization.md` for architecture

```
```

CLI shortcuts (terminal/shell use):

```bash
kb current "<fact>"          # append to current.md (≤5 bullets hard cap)
kb next "<action>"           # append to next.md
kb gotcha "<trap>"           # append to gotchas.md (append-only)
kb done <substr>             # mark matching next item [done: YYYY-MM-DD]
kb save "<summary>"          # write history/YYYY-MM-DD-HHMM.md
kb wrap "<summary>" [topic]  # save snapshot + set new current focus
kb remember [slug]           # full digest: scan sessions, propose updates, auto-prune+compact
kb digest [slug]             # alias for remember
kb prune [slug]              # move [done:] items → history/
kb compact [slug]            # cap current.md at 5 bullets, overflow → history/
kb lint                      # validate vault against _schema/ (also runs pre-commit)
kb path                      # print active brain dir
kb slug                      # print resolved slug

`brain` is a transition shim → execs `kb`.

## Save protocol — when to use what

| Situation | Command |
|---|---|
| Discovered a non-obvious trap | `kb gotcha "<trap>"` — immediately, don't wait |
| New action item | `kb next "<action>"` |
| State changed (decision made, thing completed) | `kb current "<fact>"` |
| Topic shift or chunk completed | `kb wrap "<what-done>" [new-topic]` |
| End of big session / before compaction | `kb remember` |
| Mid-session capture (alias) | `.remember` (PI keyword) |

**Do not save:** noise, obvious things, temporary debugging notes, things already in `current.md`.
**Never edit vault files directly.** Only `kb` writes.

## How context loads per session

### Default (token-efficient, ~800 tokens)
- `personal/current.md` + `personal/gotchas.md` (always, dense)
- Module index: one-line description per module (names + purpose only)
- `projects/<slug>/INDEX.md` + `current.md` + `next.md` (active items only)
- Note: `personal/preferences.md` omitted; module gotchas omitted — on-demand via `kb load --full`

### Full (on-demand, ~4,000 tokens)
- Everything above, plus `personal/preferences.md` + all `modules/*/gotchas.md`

## Automation hooks

### Cursor IDE
| Event | What happens |
|---|---|
| `sessionStart` | No vault dump (MCP-only). Agent loads via `kb_load` / `kb_search` on demand. |
| `stop` | `vault-save.sh`: session marker → `sessions/YYYY/MM/`, TF-IDF background, prune+compact, AI nudge |
| `preCompact` | `brain-save-inject.sh`: instructs agent to persist facts before compaction |
| `afterFileEdit` | aislop code quality gate |

### PI (`pi-yaml-hooks`)
| Event | What happens |
|---|---|
| `session.created` | Notify: `kb load` available |
| `session.idle` | Silent prune+compact; nudge to `.remember` |
| `session.deleted` | Final prune+compact (best-effort) |

**PI limitation:** hook stdout ≠ `additional_context`. Context injection requires agent to call `kb load` explicitly.

## The promotion flywheel

```
Session work
  → (auto) sessions/YYYY/MM/<slug>-session.md  ← TF-IDF appended on stop
  → (weekly) ./tools/session-promote            ← grep scan → sessions/candidates.md
  → (you review) kb gotcha / kb current         ← promote survivors
  → (next session) denser additional_context    ← cheaper, more accurate
```

`kb remember` shortcut: scans last 7 days of sessions, auto-prunes, proposes entries.

## Schema enforcement

`kb lint` validates (runs pre-commit):
- `projects/<slug>/`: required files, slug format, ≤5 bullets, no orphans, no stubs
- `modules/<name>/`: `MODULE.md gotchas.md patterns.md decisions.md references.md`
- `personal/`: `current.md preferences.md gotchas.md`
- No flat `.md` at vault root except `AGENTS.md README.md PLAN.md`

## Hard rules

- Never overwrite `current.md` destructively — append or merge only
- `history/` files are append-only snapshots — never edit after writing
- No fabricated links — only reference files confirmed to exist
- No top-level `.md` at vault root except `AGENTS.md`, `README.md`, `PLAN.md`
- `pi-memory-md` is installed in PI but intentionally unconfigured — do not use `pi__memory_write` or configure `repoUrl`

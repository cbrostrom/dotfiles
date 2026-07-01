---
name: kb
description: Knowledgebase (kb) vault protocol for all agents. Covers vault path detection, tier map (personal/modules/projects/infra), load/save protocol via the kb CLI, session capture, and slug resolution. Use when loading session context, saving learnings/decisions, or at session boundaries. Triggered by 'load kb', 'save kb', 'load vault', 'save brain', 'update vault', 'kb context', or at session boundaries.
group: kb
---

# Knowledgebase (kb) Protocol

Single source of truth for all agents interacting with Christian's AI knowledgebase vault at `~/Vaults/AI`.

The vault's own contract lives at `$VAULT_AI/AGENTS.md`. This skill is the agent-facing summary.

## Vault Paths

```bash
# macOS
VAULT_AI=~/Vaults/AI
VAULT_ME=~/Vaults/Me            # human Obsidian vault (separate)

# WSL
VAULT_AI=/mnt/c/Users/christian/Obsidian/AI   # TBD, confirmed on MonsterBro
VAULT_ME=/mnt/c/Users/christian/Obsidian/Me
```

## Tier Map

```
$VAULT_AI/
  AGENTS.md              # contract (read first)
  personal/              # Christian's preferences + gotchas — load every session
  modules/<name>/        # reusable knowledge units (shareable per-module)
  projects/<slug>/       # per-project live state
  infra/<host>/          # per-machine state (superbro, monsterbro, ...)
  sessions/YYYY/MM/      # auto-captured TF-IDF summaries
  tools/kb               # canonical CLI (execs via `kb` or `brain` transition symlink)
  _ops/                  # curator reports, migration logs
  archive/               # retired projects/modules
```

## Slug Resolution

Ordered precedence:
1. `--tier <t> --slug <s>` args
2. `$KB_SLUG` env
3. `personal` — when cwd is inside `$VAULT_AI`
4. Active plan `repo:` field
5. `git rev-parse --show-toplevel` basename
6. `$PWD` basename

Slug format: `lowercase-kebab` only.

## kb CLI

```bash
kb                          # dashboard (default)
kb load [slug]              # AI context dump — auto-inits
kb current "<fact>"         # append fact to current.md
kb next "<action>"          # append action item
kb gotcha "<trap>"          # append to gotchas.md
kb done <substr>            # mark next item done
kb save "<summary>"         # write history/YYYY-MM-DD-HHMM.md
kb wrap "<summary>" [topic] # save + set new current topic
kb prune [slug]             # move [done:] items → history/
kb compact [slug]           # cap current.md at 5 bullets → history/
kb lint                     # validate tree against _schema/
```

`brain` is a transition symlink → `kb`.

## Load Context (SessionStart)

Hooks handle this automatically (`kb-load.sh` in PI + Cursor). Manual:

```bash
kb load
```

Loads in order: `personal/current.md` + `personal/preferences.md` + `personal/gotchas.md` → `modules/*/gotchas.md` → `projects/<slug>/{current,next,gotchas}.md`.

## Save Protocol

| Signal | Command | Notes |
|---|---|---|
| New fact / decision | `kb current "<fact>"` | State changes, resolved decisions |
| New action item | `kb next "<action>"` | Concrete next step |
| Non-obvious trap | `kb gotcha "<trap>"` | Things that will bite again |
| End of session | `kb save "<summary>"` | Write history snapshot |
| Topic switch | `kb wrap "<what-done>" [new-topic]` | Snapshot + reset focus |

**Do not save:** noise, obvious things, temporary debugging notes, things already in current.md.

**Efficiency rule:** one CLI call per new fact. Never edit vault files directly.

## Schema Enforcement

`kb lint` validates:
- Every `projects/<slug>/` has `current.md` (≥ 200B), `next.md`, `gotchas.md`
- `current.md` ≤ 5 bullets
- `INDEX.md` ≤ 500B
- No stale `[done:]` items in `next.md`
- No ad-hoc `.md` at project root (must live in `plans/`)
- Every `modules/<name>/` has `MODULE.md`, `gotchas.md`, `patterns.md`, `decisions.md`, `references.md`
- `personal/preferences.md` ≥ 500B (no stub)
- No top-level `.md` except `AGENTS.md`, `README.md`, `PLAN.md`

Wired to pre-commit.

## Cross-Agent Notes

- **PI**: `~/dotfiles/.pi/hooks/kb-load.sh` (SessionStart)
- **Cursor / Cursor-Agent**: `~/.cursor/hooks.json` → `brain-load.sh` (soon `kb-load.sh`)
- **Any future harness**: read `$VAULT_AI/AGENTS.md`, call `kb load` at session start

## Hard Rules

- Never overwrite `current.md` destructively — merge or append only.
- Never mark items `[done:]` without completing them.
- `history/` files are append-only snapshots — never edit after writing.
- No fabricated links — only reference files confirmed to exist.
- No top-level `.md` at vault root except `AGENTS.md`, `README.md`, `PLAN.md`.

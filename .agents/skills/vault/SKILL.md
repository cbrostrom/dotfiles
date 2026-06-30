---
name: vault
description: Obsidian Brain vault protocol for all agents. Covers vault path detection, brain load/save (current.md / next.md / gotchas.md), when and what to persist, inbox routing, and the brain CLI. Use when loading session context, saving learnings/decisions, or routing Inbox/ files. Triggered by 'load vault', 'save brain', 'update vault', 'vault context', or at session boundaries.
group: vault
---

# Vault Protocol

Single source of truth for all agents interacting with Christian's Obsidian Brain vault.

## Vault Paths

```bash
# macOS
VAULT=~/Vaults/Me
VAULT_BRAINS=~/Vaults/AI/brains

# WSL (/proc/version contains "microsoft" or $WSL_DISTRO_NAME set)
VAULT=/mnt/c/Users/christian/Obsidian/Brain
VAULT_BRAINS=/mnt/c/Users/christian/Obsidian/Brain/Brains
```

Slug: `basename $(git rev-parse --show-toplevel 2>/dev/null)` or `basename $PWD`.

## Brain Structure

```
$VAULT_BRAINS/<slug>/       ← modular (preferred)
  current.md                 current state, conventions
  next.md                    action items — mark done: [done: YYYY-MM-DD]
  gotchas.md                 non-obvious traps
  history/YYYY-MM-DD.md      dated snapshots (written on compact/clear)
  INDEX.md                   optional project index

$VAULT_BRAINS/<slug>.md     ← legacy single file (fallback)
$VAULT/Inbox/               ← unrouted notes (see inbox routing below)
```

## Brain CLI

```bash
~/.local/bin/brain
brain load                  # print current.md + next.md (not done items)
brain current "<fact>"      # append fact to current.md → Current State
brain next "<action>"       # append to next.md
brain gotcha "<trap>"       # append to gotchas.md
brain history               # list history entries
```

## Load Context (SessionStart)

Run at session start:
```bash
brain load
```

Output is injected as `=== PROJECT BRAIN LOADED ===` context block. Covers current state, conventions, and open next items. Do not re-load mid-session unless context was wiped.

## Save Protocol

### What to save

| Signal | Command | Notes |
|---|---|---|
| New fact / decision | `brain current "<fact>"` | State changes, resolved decisions |
| New action item | `brain next "<action>"` | Concrete next step |
| Non-obvious trap | `brain gotcha "<trap>"` | Things that will bite again |
| Session history | write `history/YYYY-MM-DD.md` | On compact/clear/major milestone |

**Do not save:** noise, obvious things, temporary debugging notes, things already in current.md.

### When to save

| Event | What to do |
|---|---|
| `/compact` or `/clear` | Write `current.md`, `next.md`, create `history/` snapshot |
| End of substantive session | Call `brain current` + `brain next` for new items only |
| Major decision reached | `brain current` immediately — don't wait for session end |
| Gotcha discovered | `brain gotcha` immediately |

**Efficiency rule:** one CLI call per new fact. Do not rewrite entire files unless explicitly reconciling.

### current.md format

```markdown
## Current State
- [what is true right now — 3 bullets max, no filler]

## Conventions / Cross-references
- [unchanged unless new ones found]
```

Write atomically: `file.tmp` → `mv` to avoid partial writes.

## Inbox Routing

For routing `$VAULT/Inbox/` files: see `inbox-librarian` skill.
Short protocol:
1. List `Inbox/*.md` sorted by mtime (oldest first)
2. For each: infer `area`, `type`, `tags` from hashtags → filename → body
3. Propose destination per routing table — **never auto-route**
4. Wait for explicit `y` before moving/appending
5. Never edit body text

## Cross-Agent Notes

- **Claude Code**: brain-load.sh (SessionStart) + brain-save-inject.sh (PreCompact) handle this automatically. Agents reinforce by calling CLI directly when needed.
- **Cursor**: brain-load.sh runs on sessionStart. vault-save.sh nudges on `stop`. Agents call `brain` CLI directly for mid-session saves.
- **Codex / others**: run `brain load` manually at session start, call `brain current/next/gotcha` directly when signal fires.

## Hard Rules

- Never overwrite `current.md` destructively — merge or append only.
- Never mark items `[done:]` without completing them.
- `history/` files are append-only snapshots — never edit after writing.
- No fabricated vault links — only link files confirmed to exist via grep.

---
name: memory-curator
description: Vault quality guard. Reads brain files for a project, finds stale done items, contradictory facts, over-grown sections, and orphaned next items — proposes tidy consolidation. Never edits without confirmation. Can run as a weekly cron via scripts/vault/memory-curator.sh. Triggered by 'curate vault', 'clean brain', 'memory audit', 'tidy vault', 'vault cleanup'.
group: vault
---

# Memory Curator

Keeps brain files lean and signal-rich. Proposes only — you confirm before anything changes.

## Scope

One project at a time. Default: current git repo slug. Override: "curate [project]".

Files read:
- `~/Vaults/Brain/Brains/<slug>/current.md`
- `~/Vaults/Brain/Brains/<slug>/next.md`
- `~/Vaults/Brain/Brains/<slug>/gotchas.md`

## Checks

### next.md
- **Stale done:** `[done: YYYY-MM-DD]` items older than 14 days → propose removal
- **Orphaned:** items with no connection to current state → flag for review
- **Duplicates:** near-identical items → propose merge
- **Too many items:** if >15 items, propose grouping or archiving oldest

### current.md
- **Over-grown Current State:** if >6 bullets → propose trimming to top 3 most recent
- **Stale facts:** references to deleted files, old branch names, resolved decisions → propose removal or update
- **Contradictions:** two bullets saying opposing things → flag for resolution
- **Conventions section:** if identical to last month's → keep; if grown >5 bullets → propose trim

### gotchas.md
- **Resolved:** gotchas that mention a fix already in codebase → propose archiving
- **Duplicates:** same trap mentioned twice → merge

## Output format

```
## Vault Audit — [project] — [date]

### next.md
- Remove (done >14d): "deploy new caching layer [done: 2026-05-10]"
- Merge (duplicates): "fix auth timeout" + "fix login timeout" → "fix auth/login timeout"
- Archive (orphaned): "investigate graphql schema" [no related current state]

### current.md
- Trim Current State: 8 bullets → suggest removing: "Running on Node 18" (outdated)
- Contradiction: "using Tailwind v3" vs "migrated to Tailwind v4" → resolve?

### gotchas.md
- Archive (resolved): "don't use git stash with pre-commit hook" [stash guard added 2026-06-01]

**Total proposed changes: N**
Apply all? [y/n] or specify which.
```

Confirm before any write. Apply per-section or per-item.

## Cron mode (scripts/vault/memory-curator.sh)

When run as cron, writes a report to `~/Vaults/Brain/Brains/curator-report-YYYY-MM-DD.md` and does NOT apply changes. You review and invoke the skill to apply.

Cron schedule: weekly, Sunday 08:00.

## Rules
- Never delete vault content without confirmation
- Never edit body text — only propose removals/merges
- Archive = move to `history/archived-YYYY-MM-DD.md`, not delete
- Treat gotchas as precious — raise the bar for archiving them

---
name: brain/optimise
description: Semantic LLM-driven brain optimise. Reads current.md, gotchas.md, next.md + history. Surfaces diffs for user approval before writing. Invoked via .brain optimise [slug].
trigger: .brain optimise
---

# brain/optimise

Semantic cleanup for modular brain dirs. LLM-driven, user-approval required before any write.

## Steps

1. **Read** `current.md`, `gotchas.md`, `next.md`.
2. **Scan history** — grep across `history/*.md` for recurring patterns.
3. **Surface diffs** — propose changes in diff format, do NOT write yet:
   - Dup gotchas → propose merged single entry.
   - History patterns appearing ≥3 sessions → propose promotion to `gotchas.md`.
   - `current.md` sections contradicted by newer history → propose replacement.
   - `next.md` items where `current.md` or history shows completion → propose strip with `[done: YYYY-MM-DD]` stamp.
4. **Show diff** — present as `- removed` / `+ added` lines per file.
5. **Wait for user approval** — never auto-write. Ask: "Apply these changes?"
6. **Write** only approved changes, atomically (`.tmp` → `mv`).
7. **Regenerate INDEX.md** — run `bash ~/dotfiles/.claude/hooks/brain-optimise-cheap.sh` after writes (cheap-optimise handles INDEX).

## Output Format

```
## Proposed changes: Brains/<slug>/

### gotchas.md
- Remove: "- **cloudcli-update**: must use npm update..." (dup of next bullet)
+ Keep: merged version below

### next.md
- "- Bootstrap MonsterBro..." → mark [done: 2026-06-15] (history shows completed)

Apply? (y/n)
```

## Constraints

- Never rewrite files without explicit approval.
- Preserve all content not flagged — no silent omissions.
- history/ and archive/ are read-only in this flow (only promoted TO gotchas/current, never deleted).
- Done-stamp cutoff for strip = 30 days (consistent with cheap-optimise).

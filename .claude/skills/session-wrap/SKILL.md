---
name: session-wrap
description: "End-of-session wrap-up. Writes brain.md, saves to Engram + Graphiti, anchors with git diff. Triggered by .bye or .wrap"
trigger: /session-wrap
group: productivity
---

# Session Wrap (.bye / .wrap)

Run at end of session. ~60s. Prevents knowledge loss across compaction and new sessions.

## Steps (in order)

### 1. Get git anchor
Run: `git diff --stat HEAD` (or `git diff --stat HEAD~1` if HEAD is clean).
Keep output — used in steps 2 and 3.

### 2. Write .claude/brain.md (cold-start artifact)
Write `.claude/brain.md` in current project directory. Loaded automatically by SessionStart hook next session. Survives compaction as plain file.

Format (≤3 bullets per section, no filler):

```
# Brain: <project-name>
_Updated: <YYYY-MM-DD HH:MM>_

## Current State
- [what we're actively working on]

## Open Decisions
- [unresolved questions or choices]

## Gotchas
- [non-obvious, session-discovered, would waste time to rediscover]

## Next Steps
- [concrete first action — specific enough to act on immediately]

## Git Snapshot
<git diff --stat output from step 1>
```

Target: <20 lines total.

### 3. Save session summary to Engram
Call `mem_session_summary`:

```
## What we did
[2-4 bullets — concrete actions]

## Key decisions & why
[non-obvious choices + reasoning]

## Gotchas discovered
[anything that would waste time if rediscovered]

## Next steps
[concrete, specific]
```

Use `topic_key` matching project area (e.g. `dotfiles/hooks`, `shopify/fiskars-theme`).

### 4. Push relational facts to Graphiti
For each significant decision or discovery involving ≥2 entities, call `mcp__graphiti__add_memory`:

- Format: `"<entity-A> [relationship] <entity-B> because <reason>"`
- Examples:
  - `"DOTFILES_NONINTERACTIVE flag replaces TTY check in tui.sh because SSH sessions have no TTY"`
  - `"brain-save-inject.sh hooks into PreCompact to write .claude/brain.md before context loss"`
- Only if non-obvious. Skip trivial facts.

### 5. Check Engram conflicts
If `mem_session_summary` returns `judgment_required: true` — resolve per conflict rules.

### 6. Clear autosave queue if present
If Engram autosave queue has pending entries, save via `mem_save` with stable `topic_key`.

### 7. Update vault CLAUDE.md next steps (vault projects only)
If in `~/Vaults/Christian`, update `## Next Steps` in `CLAUDE.md`.

### 8. Confirm
One line: what saved, what's next. Example:
> Brain written. Engram saved. Graphiti: 2 facts. Next: wire brain-load hook.

## What NOT to save
- File paths / code patterns (readable from files)
- Things already in CLAUDE.md
- Git history (use `git log`)
- Obvious dev knowledge

## Tone
Caveman. No praise, no filler. Dense, useful only.

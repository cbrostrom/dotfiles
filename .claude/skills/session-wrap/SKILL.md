---
name: session-wrap
description: "End-of-session wrap-up. Saves summary to Engram, updates vault CLAUDE.md next steps, records key decisions. Triggered by .bye or .wrap"
trigger: /session-wrap
group: productivity
---

# Session Wrap (.bye / .wrap)

Run this at the end of every working session. Takes 30-60 seconds. Prevents knowledge loss across compaction and new conversations.

## Steps (run in order)

### 1. Reflect on session
Mentally scan: what decisions were made? What was discovered that isn't obvious from reading the code/files? What should the next session know immediately?

### 2. Save session summary to Engram
Call `mem_session_summary` with a structured summary:

```
## What we did
[2-4 bullet points — concrete actions, not vague]

## Key decisions & why
[Non-obvious choices made this session. Include the WHY.]

## Gotchas discovered
[Anything that would waste time if rediscovered]

## Next steps
[Concrete, specific — what to do first next session]
```

Use `topic_key` matching the project area (e.g. `obsidian/vault-setup`, `shopify/fiskars-theme`).

### 3. Check for Engram conflicts
If `mem_session_summary` returns `judgment_required: true` — resolve per conflict surfacing rules (check existing memories, judge each candidate).

### 4. Update vault CLAUDE.md next steps (if in Obsidian vault)
If working in `/Users/Christian.Brostrom/Vaults/Christian`, update the `## Next Steps` section in `CLAUDE.md` with what was completed and what remains. Keep it current — this is what the next session reads first.

### 5. Clear autosave queue if present
If the Engram autosave queue hook has pending entries, save those too via `mem_save` with stable `topic_key`.

### 6. Confirm to user
One line: what was saved, what's next. Example:
> Session saved. Next: set Local REST API key, finish mobile plugin installs.

## What NOT to save
- File paths and code patterns (read from files)
- Things already in CLAUDE.md
- Git history (use `git log`)
- Obvious things that any dev would know

## Tone
Caveman mode applies. No praise, no filler. Dense, useful summary only.

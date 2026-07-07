---
name: context-bridge
description: Structured session context save and restore. Extracts decisions made, files touched, open questions, and next steps from the current session → writes to vault. On load, presents a rich "where you left off" summary. Richer than brain save — captures the full reasoning thread, not just facts. Triggered by 'context bridge', 'save context', 'bridge session', 'I will continue later', 'end of session'.
group: vault
---

# Context Bridge

Preserves the full thread of a session so you can resume it exactly — even days later, even in a different agent.

## When to use

**Save:** before ending a meaningful session, before a long break, before switching context.
**Load:** at the start of a session when continuing previous work.

**Not for:** trivial sessions (single question answered, quick lookup). Use `brain current` for those.

**Automatic trigger in Claude Code:** fires alongside `brain-save-inject.sh` on `/compact` or `/clear` — adds the structured bridge block to the same save instruction.

**Cursor:** invoke manually. The `vault-save.sh` stop hook gives a lightweight nudge; context-bridge is for richer saves before breaks.

## Save protocol

Extract from the current session:

```markdown
## Context Bridge — [project] — [YYYY-MM-DD HH:MM]

### What we were doing
[1-2 sentences: the actual goal, not a summary of tools used]

### Decisions made
- [Decision: what was chosen and WHY — include the reasoning, not just the outcome]
- [...]

### Files touched
- `path/to/file` — [what changed and why]
- [...]

### Open questions
- [Unresolved question that will need an answer to continue]
- [...]

### Dead ends (don't repeat)
- [Approach tried that didn't work — saves re-discovering this]

### Exact next step
[One concrete action: what to do first when resuming. Specific enough to act on without re-reading.]

### Context to reload
- Brain: `brain load` in [project dir]
- Key files: [list any files worth re-reading on resume]
```

Write to: `~/Vaults/AI/projects/<slug>/context-bridge.md`
Overwrite each time (this is a snapshot, not a log). Append a dated entry to `history/` as backup.

## Load protocol

On "resume" or "load context bridge":
1. Read `~/Vaults/AI/projects/<slug>/context-bridge.md`
2. Read `~/Vaults/AI/projects/<slug>/current.md` + `next.md`
3. Present as: "Here's where you left off: [exact next step]. Context: [decisions + open questions]."
4. Ask: "Ready to continue?" — then proceed.

## Rules
- Summarise decisions with reasoning, not just outcomes — the "why" is what makes resuming fast
- Dead ends section is as valuable as decisions — saves re-discovering failed approaches
- Never save trivial tool outputs or file listings — only signal
- `context-bridge.md` is a living snapshot; `history/YYYY-MM-DD-HH-MM.md` is the archive

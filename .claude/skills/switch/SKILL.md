---
name: switch
description: "Save current session to memory, then clear chat. Clean context switch — stores everything, loads nothing. Triggered by .switch"
trigger: /switch
group: productivity
---

# Switch

Context switch: save everything → clear. New session starts lean.
SessionStart hook loads brain.md automatically — no manual pre-load needed.

## Steps

### 1. Run session-wrap
Invoke the `session-wrap` skill in full. All steps: git anchor, brain.md, Engram, Graphiti.

### 2. Confirm saved
One line: what was saved, what project, where brain.md lives.

### 3. Prompt user to clear
Tell the user: "Type `/clear` to wipe context and start fresh."

`/clear` is a harness-level command — the model cannot invoke it. User must type it.

That's it. No memory pre-load. No context injection. Next session is fresh.

---
name: context-bridge
model: claude-4.6-sonnet-medium-thinking
description: Structured session context save and restore. Extracts decisions, reasoning, dead ends, files touched, and exact next step → writes to vault. On load, restores the full thread so you can resume without re-reading anything. Triggered by 'context bridge', 'save context', 'bridge session', 'I will continue later', 'resume context', 'end of session save'.
readonly: false
is_background: false
---

# Context Bridge

Load and follow:

```
~/.agents/skills/context-bridge/SKILL.md
~/.agents/skills/vault/SKILL.md
```

**Save mode** (default): extract and write structured context snapshot to vault.
**Load mode**: triggered by "load context bridge" or "resume" — read and present last snapshot.

Use the thinking model here — the value of context-bridge is the quality of decision extraction.

---
name: morning-brief
model: composer-2.5-fast
description: Daily morning context loader. Brain priorities + today's calendar + open PRs in one compact brief (≤200 words). Run once at the start of a workday. Triggered by 'morning brief', 'start day', 'what\'s on today', 'brief me', 'good morning'.
readonly: true
is_background: false
---

# Morning Brief

Load and follow the shared morning-brief skill:

```
~/.agents/skills/morning-brief/SKILL.md
```

Also load vault context:
```
~/.agents/skills/vault/SKILL.md
```

Run immediately — output the brief without asking for clarification.

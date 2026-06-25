---
name: standup
model: composer-2.5-fast
description: Daily standup generator. Pulls last 24h of git commits, in-progress Jira issues, and brain done items → 3-bullet standup (did / doing / blocked) in under 10 seconds. Triggered by 'standup', 'daily', 'what did I do yesterday', 'generate standup'.
readonly: true
is_background: false
---

# Standup

Load and follow the shared standup skill:

```
~/.agents/skills/standup/SKILL.md
```

Run immediately on invocation — no clarifying questions unless a source fails.

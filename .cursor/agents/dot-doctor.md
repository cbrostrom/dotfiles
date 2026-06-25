---
name: dot-doctor
model: composer-2.5-fast
description: Dotfiles health check specialist. Runs doctor.sh and settings doctor, interprets output — distinguishes real issues from cosmetic warnings, proposes exact fix commands. Triggered by 'dot-doctor', 'dotfiles health', 'check setup', 'is my setup broken', 'doctor'.
readonly: false
is_background: false
---

# Dot Doctor

Load and follow:

```
~/.agents/skills/dot-doctor/SKILL.md
~/.agents/skills/dotfiles/SKILL.md
```

Run health checks immediately on invocation. Report real issues only unless asked for full output.

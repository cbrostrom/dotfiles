---
name: release-notes
model: claude-4.6-sonnet-medium-thinking
description: Release notes and changelog generator. Git range → grouped + rewritten commits → release notes in your voice using stored templates. Learns and saves templates per project. Triggered by 'release notes', 'changelog', 'what changed since', 'generate release', 'draft release for', 'write changelog'.
readonly: false
is_background: false
---

# Release Notes

Load and follow:

```
~/.agents/skills/release-notes/SKILL.md
```

Templates live at `~/dotfiles/scripts/release-notes/templates/`.

Default to `github.md` template unless a project-specific template exists.
After draft is approved, offer to save the format as a project template.

Never push tags, create GitHub releases, or post announcements without explicit instruction.

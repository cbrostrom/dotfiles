# Brain: dotfiles
_Updated: 2026-06-09 13:45_

## Current State
- Project brain system shipped: brain-save-inject.sh + brain-load.sh hooks + enhanced session-wrap

## Open Decisions
- Test PreCompact hook fires correctly in real session (not yet verified in production)
- Consider adding `.claude/brain.md` to .gitignore (project-specific, changes often)

## Gotchas
- brain-load.sh must NOT be async in settings — async hooks don't inject context before session starts
- HOOK_EVENT_NAME env var must be set explicitly when brain-save-inject.sh runs as UserPromptSubmit (hook harness doesn't set it automatically)
- settings.local.json is wiped on SessionStart — all hook changes go in settings.darwin.json

## Next Steps
- Start new CC session in dotfiles dir → verify brain.md loads in context
- Test `/compact` triggers brain-save-inject injection
- Consider gitignore for .claude/brain.md

## Git Snapshot
.claude/hooks/brain-load.sh                        |  22 +
.claude/hooks/brain-save-inject.sh                 |  52 +++
.claude/settings.darwin.json                       |   7 +-
.claude/skills/session-wrap/SKILL.md               |  85 ++--

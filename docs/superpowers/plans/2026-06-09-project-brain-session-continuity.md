# Project Brain — Session Continuity System

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Prevent knowledge loss during mid-session compaction and across sessions via a per-project `.claude/brain.md` file — written by hooks on compaction/clear events, read automatically at session start.

**Architecture:** Three artifacts: `brain-save-inject.sh` (injects "write brain.md now" instruction before PreCompact fires + detects `/compact`/`/clear` in UserPromptSubmit), `brain-load.sh` (SessionStart hook that injects brain.md as context), and an enhanced `session-wrap` skill that writes brain.md + pushes relational facts to Graphiti + anchors with `git diff --stat`. No `.start` command needed — load is automatic.

**Tech Stack:** bash, jq, Claude Code hooks (PreCompact, UserPromptSubmit, SessionStart), Engram `mem_session_summary`, Graphiti `add_memory`

---

## File Map

| File | Action | Responsibility |
|------|--------|---------------|
| `dotfiles/.claude/hooks/brain-save-inject.sh` | CREATE | PreCompact + UserPromptSubmit injection: tell Claude to write brain.md before context loss |
| `dotfiles/.claude/hooks/brain-load.sh` | CREATE | SessionStart: read .claude/brain.md → inject as session context |
| `dotfiles/.claude/settings.darwin.json` | MODIFY | Register PreCompact, UserPromptSubmit (/compact|/clear), SessionStart hooks |
| `dotfiles/.claude/skills/session-wrap/SKILL.md` | MODIFY | Add brain.md write step, Graphiti add_memory, git diff anchor |

---

### Task 1: brain-save-inject.sh

**Files:**
- Create: `dotfiles/.claude/hooks/brain-save-inject.sh`

This hook serves double duty:
- As **PreCompact** hook: always fires, always injects save instruction
- As **UserPromptSubmit** hook: fires only when prompt is `/compact` or `/clear`

- [ ] **Create the hook script**

```bash
#!/usr/bin/env bash
# brain-save-inject.sh — PreCompact + UserPromptSubmit hook
# Injects instruction to write .claude/brain.md before context is lost.
# As PreCompact: always fires (no input check needed).
# As UserPromptSubmit: fires only on /compact or /clear.
set -uo pipefail

# If called as UserPromptSubmit, check for /compact or /clear
if [[ "${HOOK_EVENT_NAME:-}" == "UserPromptSubmit" ]]; then
  INPUT="$(cat)"
  PROMPT="$(printf '%s' "$INPUT" | jq -r '.prompt // empty' 2>/dev/null || true)"
  [ -z "$PROMPT" ] && exit 0
  printf '%s' "$PROMPT" | grep -qE '^\s*/(compact|clear)\b' || exit 0
else
  # PreCompact: consume stdin silently
  cat >/dev/null
fi

# Only inject if in a git repo (skip for bare shells)
git rev-parse --git-dir >/dev/null 2>&1 || exit 0

BRAIN=".claude/brain.md"
REPO="$(basename "$(git rev-parse --show-toplevel 2>/dev/null)" 2>/dev/null || echo "unknown")"
NOW="$(date '+%Y-%m-%d %H:%M')"

cat <<EOF
=== BRAIN SAVE REQUIRED ===
Context about to compact/clear. Write ${BRAIN} NOW before proceeding.
Project: ${REPO} | Timestamp: ${NOW}

Write with these exact sections (≤3 bullets each, no filler):

# Brain: ${REPO}
_Updated: ${NOW}_

## Current State
- [what we're actively doing right now]

## Open Decisions
- [unresolved choices/questions from this session]

## Gotchas
- [non-obvious things discovered this session that would waste time to rediscover]

## Next Steps
- [concrete first action for next session]

## Git Snapshot
[output of: git diff --stat HEAD (or git diff --stat HEAD~1 if nothing staged)]

After writing brain.md, proceed with the compact/clear.
=== END BRAIN SAVE REQUIRED ===
EOF

exit 0
```

- [ ] **Make executable**

```bash
chmod +x /Users/Christian.Brostrom/dotfiles/.claude/hooks/brain-save-inject.sh
```

- [ ] **Verify syntax**

```bash
bash -n /Users/Christian.Brostrom/dotfiles/.claude/hooks/brain-save-inject.sh
echo "exit: $?"
```

Expected: `exit: 0`

- [ ] **Smoke test (UserPromptSubmit mode)**

```bash
echo '{"prompt":"/compact"}' | HOOK_EVENT_NAME=UserPromptSubmit bash /Users/Christian.Brostrom/dotfiles/.claude/hooks/brain-save-inject.sh
```

Expected: outputs `=== BRAIN SAVE REQUIRED ===` block

- [ ] **Smoke test (non-matching prompt, no output)**

```bash
echo '{"prompt":"fix the bug"}' | HOOK_EVENT_NAME=UserPromptSubmit bash /Users/Christian.Brostrom/dotfiles/.claude/hooks/brain-save-inject.sh
echo "exit: $?"
```

Expected: no output, `exit: 0`

- [ ] **Smoke test (PreCompact mode)**

```bash
echo '' | bash /Users/Christian.Brostrom/dotfiles/.claude/hooks/brain-save-inject.sh
```

Expected: outputs `=== BRAIN SAVE REQUIRED ===` block (assuming in git repo)

- [ ] **Commit**

```bash
git -C /Users/Christian.Brostrom/dotfiles add .claude/hooks/brain-save-inject.sh
git -C /Users/Christian.Brostrom/dotfiles commit -m "feat(hooks): brain-save-inject — pre-compact context preservation"
```

---

### Task 2: brain-load.sh

**Files:**
- Create: `dotfiles/.claude/hooks/brain-load.sh`

SessionStart hook. Reads `.claude/brain.md` from the current working directory (the project Claude was opened in) and injects it as session context. No brain.md = silent exit.

- [ ] **Create the hook script**

```bash
#!/usr/bin/env bash
# brain-load.sh — SessionStart hook
# If .claude/brain.md exists in $PWD, inject it as session context.
# Output goes to stdout → harness injects as additionalContext.
set -uo pipefail

BRAIN=".claude/brain.md"

[ -f "$BRAIN" ] || exit 0

AGE=""
if [[ "$(uname)" == "Darwin" ]]; then
  MOD=$(stat -f "%Sm" -t "%Y-%m-%d %H:%M" "$BRAIN" 2>/dev/null || true)
else
  MOD=$(stat -c "%y" "$BRAIN" 2>/dev/null | cut -d'.' -f1 || true)
fi

cat <<EOF
=== PROJECT BRAIN LOADED ===
Source: ${BRAIN} (last written: ${MOD:-unknown})
$(cat "$BRAIN")
=== END PROJECT BRAIN ===
EOF

exit 0
```

- [ ] **Make executable**

```bash
chmod +x /Users/Christian.Brostrom/dotfiles/.claude/hooks/brain-load.sh
```

- [ ] **Verify syntax**

```bash
bash -n /Users/Christian.Brostrom/dotfiles/.claude/hooks/brain-load.sh
echo "exit: $?"
```

Expected: `exit: 0`

- [ ] **Smoke test (with brain.md)**

```bash
mkdir -p /tmp/test-brain/.claude
cat > /tmp/test-brain/.claude/brain.md <<'MD'
# Brain: test-project
_Updated: 2026-06-09 12:00_

## Current State
- Testing brain-load hook
MD

cd /tmp/test-brain && bash /Users/Christian.Brostrom/dotfiles/.claude/hooks/brain-load.sh
```

Expected: outputs brain content wrapped in `=== PROJECT BRAIN LOADED ===`

- [ ] **Smoke test (no brain.md)**

```bash
cd /tmp && bash /Users/Christian.Brostrom/dotfiles/.claude/hooks/brain-load.sh
echo "exit: $?"
```

Expected: no output, `exit: 0`

- [ ] **Commit**

```bash
git -C /Users/Christian.Brostrom/dotfiles add .claude/hooks/brain-load.sh
git -C /Users/Christian.Brostrom/dotfiles commit -m "feat(hooks): brain-load — auto-inject brain.md at session start"
```

---

### Task 3: Register hooks in settings.darwin.json

**Files:**
- Modify: `dotfiles/.claude/settings.darwin.json`

Three hook registrations to add:
1. **PreCompact** → `brain-save-inject.sh` (no matcher needed)
2. **UserPromptSubmit** → `brain-save-inject.sh` with `HOOK_EVENT_NAME` env var set
3. **SessionStart** → `brain-load.sh` (sync, NOT async — must inject before session begins)

- [ ] **Read current settings.darwin.json** to get exact structure

Read: `dotfiles/.claude/settings.darwin.json`

- [ ] **Add PreCompact + UserPromptSubmit hooks**

In `settings.darwin.json`, add to the `hooks` object:

```json
"PreCompact": [
  {
    "hooks": [
      {
        "type": "command",
        "command": "$HOME/.claude/hooks/brain-save-inject.sh",
        "timeout": 10
      }
    ]
  }
]
```

And to the existing `UserPromptSubmit` array, append:

```json
{
  "hooks": [
    {
      "type": "command",
      "command": "HOOK_EVENT_NAME=UserPromptSubmit $HOME/.claude/hooks/brain-save-inject.sh",
      "timeout": 5
    }
  ]
}
```

And to the existing `SessionStart` array, append a **synchronous** (no `async: true`) entry:

```json
{
  "hooks": [
    {
      "type": "command",
      "command": "$HOME/.claude/hooks/brain-load.sh",
      "timeout": 10
    }
  ]
}
```

- [ ] **Validate JSON**

```bash
python3 -m json.tool /Users/Christian.Brostrom/dotfiles/.claude/settings.darwin.json >/dev/null && echo "valid JSON"
```

Expected: `valid JSON`

- [ ] **Run settings doctor**

```bash
cd /Users/Christian.Brostrom/dotfiles && ./modules/claude-settings/doctor.sh --fix 2>&1 | tail -5
```

Expected: no errors about settings.darwin.json

- [ ] **Commit**

```bash
git -C /Users/Christian.Brostrom/dotfiles add .claude/settings.darwin.json
git -C /Users/Christian.Brostrom/dotfiles commit -m "feat(settings): register brain hooks — PreCompact, UserPromptSubmit, SessionStart"
```

---

### Task 4: Enhance session-wrap skill

**Files:**
- Modify: `dotfiles/.claude/skills/session-wrap/SKILL.md`

Add three things to the existing `.bye` ritual:
1. **brain.md write** — structured, token-dense, per-project
2. **Graphiti `add_memory`** — relational decisions (entities + relationships)
3. **`git diff --stat`** — objective anchor of what changed

Keep the existing Engram `mem_session_summary` step unchanged. brain.md is the durable cold-start artifact; Engram is the searchable narrative; Graphiti is the relational graph.

- [ ] **Read current session-wrap SKILL.md**

Read: `dotfiles/.claude/skills/session-wrap/SKILL.md`

- [ ] **Replace SKILL.md with enhanced version**

New content for `SKILL.md`:

```markdown
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
Write `.claude/brain.md` in the current project directory. This file survives compaction
because it's a plain file — loaded automatically by SessionStart hook next session.

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
- Only save if non-obvious. Skip trivial facts.

### 5. Check Engram conflicts
If `mem_session_summary` returns `judgment_required: true` — resolve per conflict rules.

### 6. Update vault CLAUDE.md next steps (vault projects only)
If in `~/Vaults/Christian`, update `## Next Steps` in `CLAUDE.md`.

### 7. Confirm
One line: what saved, what's next. Example:
> Brain written. Session saved to Engram. Graphiti: 2 facts added. Next: wire brain-load hook.

## What NOT to save
- File paths / code patterns (readable from files)
- Things already in CLAUDE.md
- Git history (use `git log`)
- Obvious dev knowledge

## Token budget
brain.md target: <20 lines total. Engram summary: <200 words. Graphiti: only relational, not narrative.
```

- [ ] **Verify file was written correctly**

```bash
head -5 /Users/Christian.Brostrom/dotfiles/.claude/skills/session-wrap/SKILL.md
```

Expected: frontmatter with updated description

- [ ] **Commit**

```bash
git -C /Users/Christian.Brostrom/dotfiles add .claude/skills/session-wrap/SKILL.md
git -C /Users/Christian.Brostrom/dotfiles commit -m "feat(session-wrap): add brain.md write + Graphiti facts + git diff anchor"
```

---

## Verification

After all tasks done, verify end-to-end:

- [ ] **Test brain-save fires on `/compact`**
  Start a Claude Code session in a git repo. Type `/compact`. Verify Claude writes `.claude/brain.md` before compacting.

- [ ] **Test brain-load fires on session start**
  With brain.md present in project, start new Claude Code session. Verify `=== PROJECT BRAIN LOADED ===` appears in session context (check via statusline or ask Claude what's in brain.md).

- [ ] **Test PreCompact fires on auto-compact**
  Let context grow large enough to trigger auto-compaction. Verify brain.md is updated.

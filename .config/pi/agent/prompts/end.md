---
description: End-of-session vault save — synthesise decisions, write kb, re-index FTS5
run: |
  VAULT="${VAULT_AI:-$HOME/Vaults/Higgins/AI}"
  if git rev-parse --git-dir >/dev/null 2>&1; then
    SLUG="$(basename "$(git rev-parse --show-toplevel 2>/dev/null)")"
    BRANCH="$(git branch --show-current 2>/dev/null)"
    MODIFIED="$(git diff --name-only HEAD 2>/dev/null | head -10)"
  else
    SLUG="$(basename "$PWD")"
    BRANCH=""
    MODIFIED=""
  fi
  echo "=== Session close: $(date '+%Y-%m-%d %H:%M') ==="
  echo "cwd: $PWD"
  echo "slug: $SLUG"
  [[ -n "$BRANCH" ]] && echo "branch: $BRANCH"
  [[ -n "$MODIFIED" ]] && echo "modified:" && echo "$MODIFIED"
  echo ""
  echo "=== active project brain ==="
  if [[ -f "$VAULT/projects/$SLUG/current.md" ]]; then
    cat "$VAULT/projects/$SLUG/current.md"
  else
    echo "(no project brain at projects/$SLUG/)"
  fi
  echo ""
  echo "=== personal/current.md ==="
  cat "$VAULT/personal/current.md" 2>/dev/null || echo "(not found)"
  echo ""
  echo "=== next.md ==="
  [[ -f "$VAULT/projects/$SLUG/next.md" ]] && cat "$VAULT/projects/$SLUG/next.md" || echo "(none)"
  echo ""
  echo "=== inbox check ==="
  INBOX="${HOME}/Vaults/Higgins/Me/Inbox"
  if [[ -d "$INBOX" ]]; then
    COUNT="$(find "$INBOX" -maxdepth 1 -name "*.md" ! -name "_*" | wc -l | tr -d ' ')"
    echo "pending inbox items: $COUNT"
    [[ "$COUNT" -gt 0 ]] && find "$INBOX" -maxdepth 1 -name "*.md" ! -name "_*" -exec basename {} \; | sort | head -5
  else
    echo "inbox not found at $INBOX"
  fi
handoff: always
---
You are closing a coding session. The pre-step above shows: the active project slug, branch, modified files, and the current vault brain state.

## What to do — work through these steps in order:

### 1. Synthesise the session
Review everything we did this session and extract:
- **Decisions made** — choices with rationale (include the why and what was rejected)
- **Dead ends** — traps to avoid repeating (e.g. wrong CLI flags, wrong mental models)
- **Open questions** — unresolved, needs follow-up
- **Exact next step** — single most important thing to pick up next session, phrased as an action

Keep this synthesis tight. No fluff. Real signal only.

### 2. Update vault current.md(s)
If any facts about the **active project** or **personal/cross-cutting setup** changed this session, update them.

For the active project brain:
```bash
BRAIN_SLUG=<slug> kb current "<concise state fact>" 2>&1
```

For personal/cross-cutting agent setup:
```bash
cd ~/Vaults/Higgins/AI && kb current "<fact>" 2>&1
```

Only add facts that are durable and non-obvious. Skip things already in current.md.

### 3. Save history snapshot
```bash
cd ~/Vaults/Higgins/AI && kb save "<one-sentence synthesis of the session>" 2>&1
```

### 4. Re-index vault into FTS5
```bash
CTX="$HOME/.pi/agent/npm/node_modules/.bin/context-mode"
VAULT="${VAULT_AI:-$HOME/Vaults/Higgins/AI}"
SLUG=<resolved slug from pre-step>
"$CTX" index "$VAULT/personal/" --project "$VAULT" --ext .md 2>&1
"$CTX" index "$VAULT/modules/"  --project "$VAULT" --ext .md 2>&1
[[ -d "$VAULT/projects/$SLUG" ]] && "$CTX" index "$VAULT/projects/$SLUG/" \
  --project "$VAULT" --ext .md \
  --exclude "history/**" --exclude "archive/**" 2>&1
```

### 6. Inbox nudge
If the pre-step showed pending inbox items (count > 0), include one line in the report:
`📥 <N> inbox items pending — run /organise when ready to triage.`

Do not run the librarian. Do not touch `~/Vaults/Me/Inbox/`. Just surface the count.

### 7. Done
Report back:
- What was saved (which files changed)
- The one-line session summary used for `kb save`
- The exact next step extracted
- FTS5 re-index counts
- Inbox nudge (if applicable)

Keep the final report to ≤10 lines.

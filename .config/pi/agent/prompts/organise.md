---
description: Triage ~/Vaults/Me/Inbox/ — oldest-first, confirm-per-file, route to vault
run: |
  INBOX="$HOME/Vaults/Me/Inbox"
  echo "=== Inbox: $(date '+%Y-%m-%d %H:%M') ==="
  if [[ ! -d "$INBOX" ]]; then
    echo "Inbox not found at $INBOX"
    exit 0
  fi
  COUNT="$(find "$INBOX" -maxdepth 1 -name "*.md" ! -name "_*" | wc -l | tr -d ' ')"
  echo "pending: $COUNT items"
  if [[ "$COUNT" -eq 0 ]]; then
    echo "Inbox is empty — nothing to triage."
    exit 0
  fi
  echo ""
  echo "Files (oldest first):"
  find "$INBOX" -maxdepth 1 -name "*.md" ! -name "_*" -exec basename {} \; | sort
  echo ""
  echo "Vault: $HOME/Vaults/Me"
handoff: always
---
Load the inbox-librarian skill and follow its protocol exactly.

The pre-step above lists all pending inbox files, oldest first.

Work through them one at a time. For each file:
1. Read it
2. Infer area, type, tags from hashtags → filename → body (priority order)
3. Check for backlinks (grep vault for salient entity names — 1–3 terms, only real matches)
4. Show the proposal block and wait for explicit confirmation before moving anything

Hard rules:
- Never auto-route. Every file gets a proposal + explicit `y` before action.
- Never edit body text — frontmatter and backlink prepend only.
- Never fabricate `[[links]]` — only targets confirmed via grep.
- Brains APPEND (dated section), not replace.
- Files with `_` prefix: skip silently.

After all files are processed (or user stops), report: how many moved, how many skipped, how many appended to brains.

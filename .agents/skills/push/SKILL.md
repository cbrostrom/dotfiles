---
name: push
description: >-
  Push commits to remote safely. Triggered by "push", "/push", "push my changes",
  or "push to remote".
---
# Push skill

When triggered, push the current branch to remote after safety checks.

## Steps

1. Run `git status` — confirm working tree is clean (no uncommitted changes).
2. Run `git log --oneline origin/$(git branch --show-current)..HEAD` — show what will be pushed.
3. Check push-whitelist: `cat ~/.claude/push-whitelist.txt`. Only push if cwd is in the whitelist.
4. If safe, run `git push` (or `git push -u origin HEAD` if no upstream set).
5. Confirm with `git log --oneline -3`.

## Rules

- **Never force push** (`--force`, `--force-with-lease`) without explicit user confirmation.
- **Never push** if cwd is NOT in `~/.claude/push-whitelist.txt` — stop and tell the user.
- Client repos (`~/Projects/Clients`, `~/Projects/Shopify`, `~/Work`) are never whitelisted.
- If there are uncommitted changes, run the `commit` skill first.

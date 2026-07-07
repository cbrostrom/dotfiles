---
name: commit
description: >-
  Stage and commit changes in meaningful chunks. Triggered by "commit",
  "/commit", "chunk commits", or "commit my changes".
---
# Commit skill

When triggered, commit staged and unstaged changes in logical bundles. Never squash unrelated changes into one commit.

## Steps

1. Run `git status` and `git diff --stat HEAD` to see the full picture.
2. Group changes into logical chunks (e.g. hook fixes together, new features separate, config/docs separate).
3. For each bundle:
   - Stage only the relevant files with `git add <files>`
   - Commit with a conventional message: `type(scope): short description`
   - Types: `feat`, `fix`, `chore`, `docs`, `refactor`, `test`
4. After all bundles, run `git log --oneline -5` to confirm.

## Message format

```
type(scope): short imperative description (≤72 chars)

Optional body: what and why, not how. Wrap at 72 chars.
```

## Rules

- Never append `Co-Authored-By`, `Signed-off-by`, or any AI attribution trailer.
- Never use `--no-verify`.
- If nothing to commit, say so — don't create empty commits.
- If files are ambiguous (could belong to multiple bundles), ask before staging.

---
name: commit-push-pr
description: Commit, push, and open a PR. Use when the user says "commit and PR", "push and open a PR", "ship this", "create a PR", "open a pull request", or "commit push PR". Writes a concise PR title and body from commits and diff — no PR-description skill. Never adds AI attribution trailers to commits.
---

# Git Commit, Push, and PR

Go from working changes to an open pull request.

**Asking the user:** When this skill says "ask the user", use the platform's blocking question tool (`ask_user` in Pi). Fall back to chat only when no blocking tool exists.

## Context

Run this to gather context:

```bash
printf '=== STATUS ===\n'; git status; printf '\n=== DIFF ===\n'; git diff HEAD; printf '\n=== BRANCH ===\n'; git branch --show-current; printf '\n=== LOG ===\n'; git log --oneline -10; printf '\n=== DEFAULT_BRANCH ===\n'; git rev-parse --abbrev-ref origin/HEAD 2>/dev/null || echo 'DEFAULT_BRANCH_UNRESOLVED'; printf '\n=== PR_CHECK ===\n'; gh pr view --json url,title,state 2>/dev/null || echo 'NO_OPEN_PR'
```

---

## Full workflow

### Step 1: Gather context

Use the command output. Resolve default branch from `origin/HEAD` or `gh repo view --json defaultBranchRef --jq '.defaultBranchRef.name'`, else `main`.

If detached HEAD, ask to create a feature branch or stop.

If working tree is clean, check upstream and unpushed commits:

- **Default branch, nothing to push** — stop.
- **Feature branch, all pushed, open PR exists** — report URL and stop.
- **Feature branch, all pushed, no PR** — skip to Step 6.
- **Feature branch, unpushed commits** — skip Step 4 commit, go to Step 5.

### Step 2: Conventions

1. Repo AGENTS.md / recent commits if loaded.
2. Else conventional commits: `type(scope): description`.

### Step 3: Existing PR

If `gh pr view` shows `state: OPEN`, note the URL. Commit pending work (Step 4), push (Step 5), report URL. Do not rewrite the description unless the user asked.

### Step 4: Branch, stage, commit

1. On default branch → create feature branch first.
2. Split into 2–3 file-level commits only when obvious.
3. Stage named files; avoid `git add -A`.

**No attribution:** Subject + optional body only. Never append `Made with Cursor`, `Made-with:`, or `Co-authored-by:` lines.

```bash
git add file1 file2 && git commit -m "$(cat <<'EOF'
type(scope): subject

Optional body.
EOF
)"
```

Verify with `git log -1 --format=%B`. Amend if attribution slipped through (only when safe).

### Step 5: Push

```bash
git push -u origin HEAD
```

### Step 6: PR title and body

Resolve base branch (PR metadata, `origin/HEAD`, or `gh repo view`). Gather commits:

```bash
git log origin/<base>..HEAD --oneline
git diff origin/<base>...HEAD --stat
```

Write directly (no delegated PR skill):

- **Title:** Imperative, under 72 chars, from the main commit subject or branch intent.
- **Body:** 2–4 sentences on why and what changed. Optional `## Test plan` with 2–4 checkboxes if non-trivial. No badge footer, no AI attribution.

Ask the user to confirm title and body before creating.

### Step 7: Create PR

New PR:

```bash
gh pr create --title "<TITLE>" --body "$(cat <<'EOF'
<body>
EOF
)"
```

Or `gh pr create --fill` when commits alone tell the story and the user prefers minimal friction.

### Step 8: Report

Output the PR URL.

---

## Description-only update

When the user asks to refresh a PR description (no commit/push):

1. Confirm intent.
2. `gh pr view --json url,title,body,baseRefName`
3. Read `git log origin/<base>..HEAD` and branch diff.
4. Draft an updated title/body (same rules as Step 6).
5. Confirm, then `gh pr edit --title "..." --body "..."`.

Do not invoke any PR-description skill.

---
name: commit
description: Git commits in meaningful chunks, with push and PR variants. Modes by trigger "commit"/"commit this"/"save my changes" (commit only), "commit and push" (commit + push), "commit push PR"/"ship this"/"open a PR" (commit + push + PR). Groups the current diff into logical chunked commits, writes conventional messages following repo conventions, never adds AI attribution trailers.
---

# Git Commit (chunked)

Turn working-tree changes into clean, meaningful commits. Three modes:

- **commit** (default): chunk + commit, never push.
- **commit and push**: chunk + commit + `git push -u origin HEAD`.
- **push and PR** ("commit push PR", "ship this"): the full path to an open pull request.

Chunking is the headline behavior: commits reflect the work, not the file list.

## Context

Run one command to gather everything:

```bash
printf '=== STATUS ===\n'; git status; printf '\n=== DIFF ===\n'; git diff HEAD; printf '\n=== BRANCH ===\n'; git branch --show-current; printf '\n=== LOG ===\n'; git log --oneline -10; printf '\n=== DEFAULT_BRANCH ===\n'; git rev-parse --abbrev-ref origin/HEAD 2>/dev/null || echo 'DEFAULT_BRANCH_UNRESOLVED'
```

In Claude Code, skip this — the skill template pre-populates these sections.

Interpret: clean tree → check unpushed commits (`git log @{u}.. --oneline 2>/dev/null`); none + no PR requested → report nothing to do, stop. Detached HEAD → ask to create a feature branch first (use the harness blocking question tool, e.g. `ask_user` in Pi). On the default branch (`main`/`master`/resolved `origin/HEAD`) with commits requested → warn and ask: commit here or create a feature branch first.

## Conventions

1. Repo instructions already in context (AGENTS.md / CLAUDE.md) win.
2. Else match the 10 most recent commits' pattern (conventional commits, ticket prefixes, emoji).
3. Else conventional commits: `type(scope): description` — feat, fix, docs, refactor, test, chore, perf, ci, style, build.

## Chunking (headline rule)

Commits must communicate meaning. From the full diff (`git status` + `git diff HEAD`), group changed files into distinct concerns and commit each group separately:

- **Group at file level only.** No `git add -p` hunk-splitting.
- **Chunk when concerns differ**: feature + unrelated fix, refactor + new test files, config + code. A chunk = one idea a reviewer can read standalone.
- **One commit is fine** when everything serves one change. 2-3 chunks is the sweet spot; do not over-slice into micro-commits.
- **Stage named files per chunk** — never `git add -A` / `git add .` (sensitive files, unrelated strays).
- If grouping is ambiguous, outline the proposed chunks and let the user pick.

## Commit messages

- **Subject**: concise, imperative, why-focused, matches convention.
- **Body** (non-trivial changes only): blank line after subject, explain motivation and trade-offs.
- **No attribution ever**: no `Made with Cursor`, `Made-with:`, `Co-authored-by:` lines. Verify with `git log -1 --format=%B`; amend if one slipped in (only when safe).

```bash
git add file1 file2 && git commit -m "$(cat <<'EOF'
type(scope): subject line here

Optional body explaining why, not just what.
EOF
)"
```

## Mode: commit

Chunk, commit each chunk, then `git status` to verify clean. Report hash(es) + subject line(s). Stop. Never push.

## Mode: commit and push

Same as commit, then:

```bash
git push -u origin HEAD
```

If no upstream exists on a fresh branch, `-u` sets it. Report push result with commit hashes.

## Mode: push and PR

Chunk + commit + push as above, then:

1. Resolve base branch: `origin/HEAD` (strip `origin/`), else `gh repo view --json defaultBranchRef --jq '.defaultBranchRef.name'`, else `main`.
2. Check for an open PR: `gh pr view --json url,title,state`. If OPEN: push and report the URL — do not rewrite the description unless asked.
3. New PR — draft from the commit series:
   ```bash
   git log origin/<base>..HEAD --oneline
   git diff origin/<base>...HEAD --stat
   ```
   Title: imperative, under 72 chars, from the main intent. Body: 2-4 sentences on why and what; optional `## Test plan` with 2-4 checkboxes. No badge footer, no attribution.
4. Confirm title + body with the user, then `gh pr create --title "..." --body "..."` (or `--fill` when the commits tell the story). Report the URL.

## PR description refresh

"Refresh the PR description" with no new work: confirm intent → `gh pr view --json url,title,body,baseRefName` → draft updated title/body from `git log origin/<base>..HEAD` → confirm → `gh pr edit`. Do not delegate to any PR-description skill.

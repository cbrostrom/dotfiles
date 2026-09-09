# Plan: PR-based release notes with ticket extraction

Target: `~/.agents/skills/release-notes/SKILL.md` (rewrite core workflow).
Context: stellar-shopify (Fiskars) confirmed every sampled PR (#1407-1418) carries
its Jira key in `headRefName`, not in commit message/PR title. Squash-merge commits
lose the key. Ticket-key extraction must come from GitHub PR metadata, not git log,
and never from Jira title-matching (no fuzzy guessing — false attribution risk in
client-facing notes).

## Current state (what exists today)

- `git log <range> --oneline --no-merges` is the source of truth.
- Classification is prefix-based on commit message (`feat:`, `fix:`, etc.).
- No ticket-number extraction anywhere.
- No GitHub integration — pure git.
- Template system already exists (`~/dotfiles/scripts/release-notes/templates/`), keep as-is.

## New behavior

### 1. Argument handling

```
/release-notes                        → auto-detect repo (cwd), auto-detect range
/release-notes <range>                 → e.g. "v1.47.0..v1.47.1", explicit range, same repo
/release-notes <github-pr-or-repo-url> → explicit target
```

- If no URL given as 2nd arg: run `gh repo view --json nameWithOwner` in cwd to resolve
  the repo. Fail loud if not a git repo / gh not authenticated (`gh auth status`).
- If a URL is given: parse owner/repo from it (supports full PR URL, repo URL, or `owner/repo`).

### 2. Determine the range (PR-based, not commit-based)

Replace `git log` with `gh pr list`:

```bash
gh pr list --repo <owner/repo> --state merged --search "merged:<range>" \
  --json number,title,body,headRefName,mergedAt,url,author \
  --limit 200
```

Range resolution order (same precedence as today, adapted to dates):
1. Explicit range/date given by user.
2. Since last tag: `git describe --tags --abbrev=0` → tag date → `merged:>=<date>`.
3. Since last release commit found by skill's own `chore: release vX.Y.Z` marker.
4. Default: last 7 days.

Every release note item = one merged PR. No more raw commit parsing except as a
fallback when `gh` is unavailable (keep git-log path as degraded fallback, flagged
in output as "gh unavailable — falling back to commit log, ticket keys unavailable").

### 3. Ticket key extraction (deterministic, no guessing)

For each PR, search in this order, stop at first match:

1. `headRefName` — regex against a **configurable prefix list**:
   `(STLR|FECOM|RD-STLR)-\d+` for this repo. Prefix list should live in a small
   per-project config (see §6) so other repos/clients can define their own.
2. PR `title`.
3. PR `body`.
4. Commit messages within the PR (only if the above three are empty).

If no match anywhere: mark the item `[no ticket ref]` explicitly in the draft.
**Never** attempt fuzzy/semantic matching against Jira issue titles to "guess" a key —
flag and move on. A human can fill it in during review.

### 4. Optional Jira enrichment (exact-key lookup only)

Once a key is confirmed (from step 3), optionally enrich via the Jira MCP
(`atlassian-fiskars` per existing `jira-assistant` skill routing):

- Fetch issue summary only (not AC, not comments) for a cleaner client-facing
  one-liner than the raw PR title, when the PR title is terse/internal-sounding.
- Enrichment is additive and optional — skip silently if Jira MCP unavailable
  or the lookup fails (don't block the draft on Jira being down).
- This is always an **exact key → issue** lookup. Never search/list Jira to find
  a candidate ticket for an unmatched PR.

### 5. Classification (unchanged logic, new source)

Keep the existing prefix table, but classify by **PR title** instead of commit
message (PR title is the human-curated one; commit messages inside a squash PR
are noise).

| Prefix / pattern | Category |
|---|---|
| `feat:`, `feature:` | New features |
| `fix:`, `bugfix:` | Bug fixes |
| `perf:` | Performance |
| `refactor:` | Internal improvements |
| `chore:`, `ci:`, `build:` | Skip (unless asked) |
| non-prefixed | classify by content |

Also carry over: store scope (`feat(royal-copenhagen): ...`) as a grouping
dimension where relevant — this repo's PR titles already encode store name,
worth surfacing as a sub-heading or tag per item since Fiskars runs multiple
stores off one repo.

### 6. Per-project config (new, minimal)

Small config file, e.g. `~/dotfiles/scripts/release-notes/projects/<repo-slug>.json`:

```json
{
  "ticketPrefixes": ["STLR", "FECOM", "RD-STLR"],
  "jiraMcp": "atlassian-fiskars",
  "template": "github.md"
}
```

- Looked up by `owner/repo` (or repo-slug) at run time.
- If missing: fall back to a generic prefix guess (`[A-Z]{2,}-\d+`) and no Jira
  enrichment, and tell the user "no project config found — using generic ticket
  pattern, add `<repo-slug>.json` to tune this."

### 7. Output: draft .md file for copy-paste

Instead of only printing to chat, write the draft to a temp/output file for easy
copy, e.g. `./release-notes-draft-<range>.md` in cwd (or `/tmp` if cwd isn't
writable/desired) — user explicitly wants a file, not just chat output.

Suggested shape per item:

```markdown
### ✨ New features

- **[STLR-7222]** Product details, badges, footer, add-to-cart, carousel headline
  (royal-copenhagen) — PR #1418
- **[FECOM-707]** Updated localization and product dimensions display
  (georg-jensen) — PR #1417
- **[no ticket ref]** Redesigned header, larger type — PR #1416
```

Keep existing template-driven output (github.md/slack.md/changelog.md) as the
formatting layer; this only changes the **data gathering** stage.

### 8. Fallback / degraded modes

- No `gh` / not authenticated → fall back to git-log mode, warn explicitly that
  ticket keys and PR links will be missing.
- Repo has no PRs (linear history, no GitHub) → same fallback.
- `gh pr list` search syntax must be validated (`merged:>=2026-08-01` etc.) —
  test against a real range before shipping.

## Implementation checklist (for Cursor agent)

1. Rewrite `~/.agents/skills/release-notes/SKILL.md`:
   - New "Argument handling" section (repo auto-detect via `gh repo view`).
   - Replace `git log` step with `gh pr list --json ...` step.
   - Add ticket-key extraction section with prefix regex + precedence order.
   - Add optional Jira enrichment step (exact-key only, skip-on-failure).
   - Add per-project config lookup section.
   - Update output step to always write a `.md` draft file, not just chat.
   - Keep template system section unchanged (github.md/slack.md/changelog.md).
   - Keep "Rules" section, add: "Never guess ticket keys via Jira title match."
2. Create `~/dotfiles/scripts/release-notes/projects/` dir with a first config
   for stellar-shopify (prefixes: STLR, FECOM, RD-STLR; jiraMcp: atlassian-fiskars).
3. Manually test against this repo: `gh pr list --repo <org>/stellar-shopify
   --state merged --search "merged:>=2026-08-20" --json number,title,body,headRefName,url`
   — confirm regex extraction against the real headRefName values already sampled
   (#1407-1418) as a regression fixture.
4. Verify degraded fallback path (simulate `gh` failure) still produces a usable
   commit-log-based draft with an explicit warning banner at the top of the file.

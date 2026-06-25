---
name: release-notes
description: Release notes and changelog generator. Takes a git range or tag → groups commits by type → writes release notes in your voice using stored templates. Can learn and save new templates. Triggered by 'release notes', 'changelog', 'what changed since', 'generate release', 'draft release'.
group: productivity
---

# Release Notes Generator

Turns git history into human-readable release notes. Template-driven — learns your style.

## Template system

Templates stored at `~/dotfiles/scripts/release-notes/templates/`.
Default templates: `github.md`, `slack.md`, `changelog.md`.

On first run for a project: ask which template or use `github.md`.
After generating: "Save this style as a template?" → stores as `<project>-<name>.md`.

## Workflow

### 1. Determine range
- Explicit: "from v1.2 to v1.3" → `git log v1.2..v1.3`
- Since tag: "since last release" → `git describe --tags --abbrev=0` → log since that tag
- Since date: "this week" → `--since="7 days ago"`
- Default if unclear: since last tag to HEAD

```bash
git log <range> --oneline --no-merges
```

### 2. Classify commits

| Prefix / pattern | Category |
|---|---|
| `feat:`, `feature:` | ✨ New features |
| `fix:`, `bugfix:` | 🐛 Bug fixes |
| `perf:` | ⚡ Performance |
| `refactor:` | 🔧 Internal improvements |
| `chore:`, `ci:`, `build:` | Skip (unless user asks) |
| `docs:` | 📖 Documentation (include if user-facing) |
| `deps:`, `bump` | Skip (unless breaking) |
| Non-prefixed | Classify by message content |

Filter: skip device snapshot commits, merge commits, version bump commits.

### 3. Write notes (template-driven)

Load template → fill with classified commits → write in plain English, not commit-speak.

"fix: prevent double submit on checkout" → "Fixed an issue where submitting the checkout form too quickly could result in duplicate orders."

Always rewrite commit messages into user-facing language.

### 4. Offer formats

After first draft: "Want a Slack announcement version too? Or a one-liner for a PR description?"

### 5. Save/learn template

After approval: "Save this format as template for [project]? It will be reused on the next release."
Template stored as `~/dotfiles/scripts/release-notes/templates/<project>.md`.

## Output example (github.md template)

```markdown
## What's changed

### ✨ New features
- Added dark mode toggle to the account settings page
- Product filters now persist across page navigation

### 🐛 Bug fixes
- Fixed checkout double-submit issue on slow connections
- Resolved cart quantity not updating after variant change

### ⚡ Performance
- Improved collection page load time by ~40% through image lazy loading

**Full changelog:** https://github.com/org/repo/compare/v1.2...v1.3
```

## Rules
- Always show draft for review before committing/publishing
- Never push tags, create GitHub releases, or post to Slack without explicit "do it"
- Rewrite commit messages into user-facing language — never dump raw git log
- Chore/ci/build commits skipped by default — user can include with "show all changes"
- If commits are sparse: pad with context from brain `current.md` if available

---
name: release-notes
description: "Generate release notes and changelogs. Prefers the repo generator when present; otherwise git-range + templates. Triggers: release notes, changelog, what changed since, generate release, /release-notes."
group: productivity
---

# Release Notes

Never reimplement gathering. Run the repo's generator when it exists.

## stellar-shopify (and any repo with the same script)

If `build/scripts/generate-release-notes.ts` exists:

```bash
npm run release:notes -- [--from=<ref>] [--to=<ref>] [--tag=vX.Y.Z] [--output=<path>]
```

That script is the source of truth. Do not parse `git log` yourself, do not `gh pr list --search merged:>=date`, do not guess Jira keys from issue titles.

### Map user intent → flags

| User says | Command |
|---|---|
| `/release-notes` / "since last release" / on a release PR | `npm run release:notes` (last tag..HEAD, or previous..latest if HEAD **is** the latest tag) |
| "notes for v1.47.1" / after that tag exists | `npm run release:notes -- --tag=v1.47.1` |
| explicit range | `npm run release:notes -- --from=v1.47.0 --to=v1.47.1` |
| preview file elsewhere | add `--output=/tmp/notes.md` |

Then open the written file and show it. Do not rewrite tables unless asked for a Slack / GitHub-prose version — if so, rewrite **from the file**, do not re-query git.

`gh` must be installed and authenticated. If the script fails on that, stop and say so.

## Other repos (no generator)

Templates: `~/dotfiles/scripts/release-notes/templates/` (`github.md`, `slack.md`, `changelog.md`).

1. Range: explicit `from..to`, else last tag..HEAD.
2. `git log <range> --oneline --no-merges`
3. Classify by conventional-commit prefix. Skip chore/ci/build unless asked.
4. Rewrite into user-facing English using the template.
5. Show draft. Never push tags, create GitHub releases, or post to Slack unless the user says "do it".

## Rules

- Always show the draft before committing/publishing
- Never guess ticket keys via Jira title match
- Membership is a git tag range. GitHub is enrichment only
- Chore/ci/build skipped in the generic path unless "show all"

---
description: Extract PI sessions into Higgins vault handoff artifacts (decisions, dead ends, next step)
argument-hint: "[--since YYYY-MM-DD] [--project name] [--dry-run] [--reindex]"
---
Run the session extraction script to turn session history into a handoff artifact in the Higgins vault:

```bash
bun run ~/.pi/agent/scripts/extract.ts ${@:---since today}
```

This writes to `~/Vaults/Higgins/AI/sessions/` and appends durable facts to
`personal/{current,gotchas}.md`. Judge the result the way a handoff artifact should be judged:
could a session with zero context act on it without reopening decisions the old session already
settled? That means capturing the *why* behind a decision, not just the *what*, and naming dead
ends explicitly so they aren't retried.

After extraction, report:
- how many sessions were extracted and any errors
- the single most important next step, if the script surfaced one
- a one-line nudge if the output looks thin (few decisions/errors captured) so the user knows the
  handoff may need a manual `/end` pass instead of relying on this alone

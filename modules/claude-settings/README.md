# claude-settings module

3-layer merge for `~/.claude/settings.json`.

## Files

- `settings.base.json` — shared, tracked
- `settings.{darwin,linux,wsl}.json` — platform, tracked
- `settings.override.json` — per-host, gitignored
- `_merge-config.json` — per-key merge strategy
- `settings.local.json` — generated, gitignored

## Commands

| Command | Purpose |
|---|---|
| `modules/claude-settings/merge.sh` | Run merge directly |
| `modules/claude-settings/doctor.sh` | Report drift |
| `modules/claude-settings/doctor.sh --fix` | Reconcile drift |
| `modules/claude-settings/snapshot-hosts.sh` | Migration snapshot (Mac + superbro + linuxbro) |
| `modules/claude-settings/migrate-diff.sh` | Migration diff: snapshot vs computed |
| `scripts/agent-core-sync.sh` | Sync Cursor model/language/MCP from `.claude/agent-core.json` |
| `bats modules/claude-settings/tests/` | Run test suite (strategies + e2e) |

The SessionStart hook at `~/.claude/hooks/claude-settings-merge.sh` runs `merge.sh` automatically when any tracked input is newer than the last attestation. Async — never blocks Claude startup.
`merge.sh` also runs `scripts/agent-core-sync.sh` best-effort to keep Cursor aligned with the same model/language/MCP defaults.

## Strategies (see `_merge-config.json`)

- `shallow-merge` — overlay wins per top-level key (e.g., `enabledPlugins`)
- `concat-dedupe` — array union preserving first-occurrence order (e.g., `permissions.allow`)
- `deep-merge-by-key` — object-keyed deep merge (e.g., `mcpServers`)
- `replace-by:command` — array entries identified by `hooks[0].command`
- `replace-by:matcher+command` — array entries identified by `matcher` plus inner `command` set
- _default_ — overlay wins (replace)

## Editing

- Shared change → edit `settings.base.json`, commit, push, pull elsewhere.
- Platform-only → edit `settings.{platform}.json`.
- Host-only → edit `settings.override.json` on that host (never commit).
- Never edit `settings.local.json` directly — generated and wiped on next merge.

Spec: `docs/superpowers/specs/2026-05-15-platform-tiered-settings-design.md`.
Plan: `docs/superpowers/plans/2026-05-15-platform-tiered-settings-plan.md`.

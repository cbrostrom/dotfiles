# Platform-tiered settings.local.json — design

**Date:** 2026-05-15
**Status:** approved (brainstorm), pending implementation plan
**Audit context:** `.planning/2026-05-15-claude-setup-audit/`

## Goal

Replace today's per-host, gitignored, manually-drifting `settings.local.json`
with a generated artifact assembled from three tracked layers plus one per-host
override. Keep shared rules consistent across hosts; let platform- and
host-specific bits diverge cleanly.

## Constraints

- Must work on macOS (akqamacbook), Linux (superbro, linuxbro), and WSL
  (monsterbro-wsl, once SSH is fixed).
- `~/.claude/settings.json` currently symlinks to
  `dotfiles/.claude/settings.local.json` and must continue to.
- Hook paths must vary per platform (`/Users/Christian.Brostrom/...` vs
  `/home/christian/...`).
- macOS-only MCPs (apple-mcp, atlassian-*, google-calendar) must not register
  on Linux hosts.
- Bootstrap is module-driven (`bootstrap.sh`); the new mechanism slots in as
  a module.
- No `Co-Authored-By: Claude` trailer in commits.
- Push only from repos on `~/.claude/push-whitelist.txt`.

## Architecture

Three-layer merge, single output. Layers in precedence order (later wins):

```
settings.base.json
        │
        ▼
settings.{darwin,linux,wsl}.json
        │
        ▼
settings.override.json   (gitignored, per-host)
        │
        ▼
[merge engine: jq + _merge-config.json]
        │
        ▼
settings.local.json   (generated, gitignored, never hand-edited)
        │
        ▼
~/.claude/settings.json  (symlink target)
```

Trigger: SessionStart hook, mtime-gated. Drift check + `--fix`: doctor module.

## File layout

| Path | Tracked | Role |
|---|---|---|
| `dotfiles/.claude/settings.base.json` | yes | Shared rules: plugin enablement, language, env, core permissions, memory model, marketplaces, model selection |
| `dotfiles/.claude/settings.darwin.json` | yes | Mac-only: hook commands w/ Mac paths, MCPs (apple-mcp, atlassian-*, google-calendar), statusLine |
| `dotfiles/.claude/settings.linux.json` | yes | Linux-only: hook commands w/ Linux paths, tailnet-only MCPs (engram, graphiti, dockhand) |
| `dotfiles/.claude/settings.wsl.json` | yes | WSL-only: extends linux semantics; Windows path bridges, wslg env. Stub until wsl SSH fixed. |
| `dotfiles/.claude/settings.override.json` | gitignored | Per-host manual tweaks. Empty by default. |
| `dotfiles/.claude/settings.local.json` | gitignored | Generated. **Never hand-edit.** |
| `dotfiles/.claude/_merge-config.json` | yes | Per-key merge strategy (concat-dedupe / replace-by-key / deep-merge / shallow-merge). |
| `dotfiles/.claude/.settings-attestation` | gitignored | SHA of last successful merge inputs. Doctor uses for drift detection without re-running merge. |
| `dotfiles/modules/claude-settings/merge.sh` | yes | Merge engine. jq-based. Idempotent. |
| `dotfiles/modules/claude-settings/doctor.sh` | yes | Drift report + `--fix` regen. |
| `dotfiles/modules/claude-settings/snapshot-hosts.sh` | yes | Migration helper: snapshot every host's current `settings.local.json` to `.attic/`. |
| `dotfiles/modules/claude-settings/migrate-diff.sh` | yes | Migration helper: diff snapshot vs computed merge. |
| `~/.claude/hooks/claude-settings-merge.sh` | yes | SessionStart hook. Async. Mtime-gated. |

Underscore prefix on `_merge-config.json` keeps engine config visually distinct
from the merged-shape fragments.

## Merge engine

**Platform detection:**

```bash
case "$(uname -s)" in
  Darwin)  PLATFORM=darwin ;;
  Linux)
    if [ -n "${WSL_DISTRO_NAME:-}" ] || grep -qi microsoft /proc/version 2>/dev/null; then
      PLATFORM=wsl
    else
      PLATFORM=linux
    fi ;;
  *) PLATFORM=linux ;;  # safe headless fallback
esac
```

**Pipeline:**

1. Read `settings.base.json`.
2. Apply `settings.{platform}.json` using per-key strategy from `_merge-config.json`.
3. Apply `settings.override.json` (treat missing file as `{}`).
4. `envsubst` to expand `$HOME`, `$HOSTNAME`, and any other vars used in tracked
   fragments. Tracked files **must not** contain hardcoded paths like
   `/Users/...` or `/home/...`.
5. Write to `settings.local.json` atomically (write to `.tmp`, then rename).
6. Update `.settings-attestation` with SHA of all inputs.

**Per-key strategy** (defined in `_merge-config.json`):

| Path | Strategy | Rationale |
|---|---|---|
| `permissions.allow` | `concat-dedupe` | Allowlists are additive. |
| `permissions.ask` | `concat-dedupe` | Same. |
| `permissions.deny` | `concat-dedupe` | Same. |
| `permissions.additionalDirectories` | `concat-dedupe` | Same. |
| `hooks.SessionStart` | `replace-by:command` | Hooks identified by command path; platform owns identity. |
| `hooks.PreToolUse` | `replace-by:matcher+command` | Matcher disambiguates. |
| `hooks.UserPromptSubmit` | `replace-by:command` | |
| `hooks.Notification` | `replace-by:command` | |
| `mcpServers` | `deep-merge-by-key` | Object keyed by server name; per-server config merges deeply. |
| `extraKnownMarketplaces` | `deep-merge-by-key` | Same. |
| `enabledPlugins` | `shallow-merge` | Object key = plugin id; later layer wins per-key. |
| _default for unlisted scalars_ | `replace` | Later wins. |
| _default for unlisted arrays_ | `replace` | Later wins fully. Be explicit in `_merge-config.json` when you want additive. |

**Failure modes:**

- Invalid JSON in any input → exit 1, do not touch `settings.local.json`, print
  offending file and parse error line.
- Unknown strategy in `_merge-config.json` → exit 1.
- `envsubst` missing → warn, skip substitution, continue. Better than break.
- Merge succeeds but write fails (disk full, permissions) → previous
  `settings.local.json` left intact.

## SessionStart hook

`~/.claude/hooks/claude-settings-merge.sh`. Async. Mtime-gated:

```bash
#!/usr/bin/env bash
set -eu
DOTFILES_DIR="${DOTFILES_DIR:-$HOME/dotfiles}"
CLAUDE_DIR="$DOTFILES_DIR/.claude"
MERGE="$DOTFILES_DIR/modules/claude-settings/merge.sh"
ATTEST="$CLAUDE_DIR/.settings-attestation"

# Cross-platform stat
mtime() { stat -f %m "$1" 2>/dev/null || stat -c %Y "$1" 2>/dev/null || echo 0; }

newest_input=$(for f in "$CLAUDE_DIR"/settings.base.json \
                       "$CLAUDE_DIR"/settings.*.json \
                       "$CLAUDE_DIR"/_merge-config.json; do
  [ -e "$f" ] && mtime "$f"
done | sort -n | tail -1)

last_merge=$(mtime "$ATTEST")

[ "$newest_input" -le "$last_merge" ] && exit 0  # up-to-date, no-op

"$MERGE" 2>&1 || {
  echo "[claude-settings] merge failed — keeping previous settings.local.json"
  exit 0  # never block session start
}
echo "[claude-settings] regenerated settings.local.json"
```

Wired in via `settings.local.json`'s own SessionStart array (the hook regenerates
that array on each run, so it's stable). Async — does not delay session start.

## Doctor + `--fix`

New bootstrap module `claude-settings`. Doctor checks (read-only):

- `_merge-config.json` exists and parses.
- All referenced platform fragments parse.
- Detected platform fragment exists.
- Current `settings.local.json` SHA matches attestation.
- If mismatch: jq-diff between disk and computed merge; report drifted keys.

`./bootstrap.sh --only=claude-settings --fix` runs `merge.sh` once.

## Migration (path D — snapshot + rebuild + diff)

1. `snapshot-hosts.sh` SSHes superbro + linuxbro and copies their current
   `settings.local.json` to `dotfiles/.attic/settings-pre-merge/<hostname>.json`.
   Mac is captured the same way locally.
2. Author `settings.base.json` + `settings.{darwin,linux,wsl}.json` +
   `_merge-config.json` from Mac's known-good config, splitting by responsibility.
3. Dry-run merge per host: `merge.sh --dry-run --output=/tmp/merged-<host>.json`.
4. `migrate-diff.sh` reports per host:
   - Keys present in old snapshot but missing from merged result.
   - Keys present in merged but not in old.
5. Decision pass: for each diff, classify the change as host-tweak (→ override),
   platform-tweak (→ platform fragment), shared-rule drift (→ base), or stale
   (drop). Document each decision in the audit progress log.
6. Cutover per host: rename `settings.local.json` to
   `settings.local.json.bak.YYYY-MM-DD`, run `--fix`, verify in a fresh Claude
   session.
7. Once all hosts verified, commit the tracked layers + engine + module. The
   `.bak` files stay until next dotfiles cleanup.

**Rollback:** restore the `.bak` file per host, disable the SessionStart hook
in `settings.local.json` by stripping the hook entry, commit nothing.

## Rules for Claude (added to CLAUDE.md)

A new "Settings architecture" section in `~/dotfiles/.claude/CLAUDE.md` codifies:

1. **NEVER edit `settings.local.json` directly.** It is generated. Edits are
   wiped on the next SessionStart.
2. Adding a shared rule → edit `settings.base.json`.
3. Adding a platform-specific rule → edit `settings.{platform}.json`.
4. Adding a per-host one-off → edit that host's `settings.override.json`.
   Never commit.
5. Tracked fragments must not contain hardcoded paths. Use `$HOME` and
   `$HOSTNAME`; the merger expands.
6. After editing any tracked layer, run
   `./bootstrap.sh --only=claude-settings --fix` or wait for SessionStart.
7. If drift is reported by `--doctor`, do not paper over it. Reconcile via
   `--fix` after deciding which layer the drifted value belongs in.
8. Cross-host changes flow base → platform → override. Edit, commit, push;
   other hosts pull and regenerate on next session.

A complementary rule lands in `agent-style/claude-code.md` as a field-observed
entry: **RULE-J: Settings layer discipline** — short reminder that
`settings.local.json` is generated and that paradigm rules above apply.

## Testing

- Unit-level: jq merge functions for each strategy (concat-dedupe,
  replace-by-key, deep-merge-by-key, shallow-merge) with table-driven inputs.
- Integration: `merge.sh` against the actual base+platform fragments produces
  bytewise-identical output on repeated runs (idempotency).
- Per-host smoke test: fresh Claude session opens after regeneration, plugin
  list matches expected, no `[claude-settings] merge failed` in logs.
- Drift test: hand-edit `settings.local.json`, run `--doctor`, expect drift
  report. Run `--fix`, expect reconciliation.

## Out of scope

- Encrypted secrets in settings (stay in `~/.local-secrets`, referenced via
  `$VAR` substitution).
- Migration of `~/.claude/hooks/*.sh` contents (only their references in
  settings move; the scripts themselves continue to live in the existing
  `claude` module).
- Plugin auto-install on first session — handled by Claude Code itself once
  `enabledPlugins` is correct.
- WSL host fix — covered by a separate "monsterbro-wsl SSH auth" task.

## Open questions

None at design time. Implementation plan will surface concrete jq function
edge cases (e.g., array-of-strings vs array-of-objects in `replace-by` paths).

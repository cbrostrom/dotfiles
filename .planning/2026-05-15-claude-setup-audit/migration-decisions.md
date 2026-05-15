# Migration decisions — 2026-05-15

For each (host, key) reported by `migrate-diff.sh`, decide:
- **base**: lift into `settings.base.json`
- **platform**: lift into `settings.{darwin,linux,wsl}.json`
- **override**: keep on that host's `settings.override.json`
- **drop**: stale, remove

Snapshot input: `.attic/settings-pre-merge/<host>.json` per host.
Computed output: result of `merge.sh` for that host's platform.

Source diff: `/tmp/migrate-diff.txt` (254 lines). Mac shows zero diffs — already
cut over in Task 14. Linux hosts (`linuxbro`, `superbro`) carry the real
migration work.

## Mac (GY-M-WHKK2PF6N7, platform=darwin)

`migrate-diff.sh` reports:

```
--- keys present in old snapshot but missing from computed ---
[]
--- keys in computed not in snapshot ---
[]
--- value differences for shared keys (first 40 lines) ---
(empty)
```

No diffs. Mac was migrated in Task 14 and the snapshot captures the
post-migration state. Nothing to decide. The current `settings.base.json` +
`settings.darwin.json` produce byte-identical output to the snapshot.

## superbro (platform=linux)

Snapshot at `.attic/settings-pre-merge/superbro.json` (129 lines, no hooks
section at all — superbro never had a hook pipeline).

| Path | Old (snapshot) | New (computed) | Decision | Reason |
|------|----------------|----------------|----------|--------|
| `effortLevel` | `"medium"` | `"high"` | **base** | Base bumped to `high` deliberately (Task 12-ish). Cross-host preference. New value wins. |
| `awaySummaryEnabled` | _absent_ | `false` | **base** | New base addition. Applies to all hosts. |
| `enabledPlugins["ck@cavekit-marketplace"]` | _absent_ | `true` | **base** | Cavekit added cross-host. Already in base. |
| `enabledPlugins["github@claude-plugins-official"]` | `true` | `false` | **base** | Base now ships github plugin off; the Linux platform layer re-enables the `mcpServers.github` MCP separately, which is the actual capability the user relied on. Plugin enable flag staying `false` in base is intentional. |
| `extraKnownMarketplaces["cavekit-marketplace"]` | _absent_ | present | **base** | Mirrors cavekit plugin enable. Cross-host. |
| `spinnerVerbs` | _absent_ | `{ mode: "replace", verbs: [...] }` | **base** | Cosmetic, cross-host preference. |
| `permissions.additionalDirectories[0]` | _absent_ | `"$HOME/dotfiles/.claude"` | **platform** (linux) | Adds the dotfiles `.claude` dir to allowed read paths. Already in `settings.linux.json`. Linux/WSL specific path; Mac uses a different `additionalDirectories`. |
| `hooks.Notification` | _absent_ | `[]` | **platform** (linux) | Empty placeholder injected by merge. Harmless. Already in `settings.linux.json`. |
| `hooks.PreToolUse[Bash].git-push-guard.sh` | _absent_ (superbro had NO hooks) | `$HOME/.claude/hooks/git-push-guard.sh` | **platform** (linux) | Linux baseline now requires the push-guard. Superbro previously had no hooks at all, but the guard is a security invariant per CLAUDE.md "Push / publish whitelist". Promote to linux platform. |
| `hooks.PreToolUse[Bash].rtk-rewrite.sh` | _absent_ | `$HOME/.claude/hooks/rtk-rewrite.sh` | **platform** (linux) | RTK rewrite hook is part of the linux baseline. Cross-linux. |
| `hooks.SessionStart.entroly-start.sh` | _absent_ | `$HOME/.claude/hooks/entroly-start.sh` (async) | **platform** (linux) | Entroly start hook is now linux baseline. Async. |
| `hooks.UserPromptSubmit.effort-classifier.sh` | _absent_ | `$HOME/.claude/hooks/effort-classifier.sh` | **platform** (linux) | Auto-effort classifier, runs everywhere we want effort tiering. Cross-linux. |
| `mcpServers.atlassian-akqa` | full block with env vars | _absent_ from computed | **override** | Work credentials, host-specific token availability. Belongs in superbro `settings.override.json`. Confirmed not in linux platform layer — correct (do not leak AKQA creds to other linux hosts). |
| `mcpServers.atlassian-fiskars` | full block | _absent_ from computed | **override** | Same reasoning as atlassian-akqa — client-specific, per-host. |
| `mcpServers.engram-personal` | ssh to superbro + ENGRAM_DATA_DIR=/home/christian/.engram/personal | _absent_ from computed | **override** | Engram MCP is per-host (data dir path varies, ssh target varies). Belongs in override. (Note: on superbro itself, "ssh superbro" is a loopback ssh — a bit wasteful; flagged for user review.) |
| `mcpServers.engram-work` | ssh to superbro + ENGRAM_DATA_DIR=/home/christian/.engram/work | _absent_ from computed | **override** | Same as engram-personal. |
| `mcpServers.github` | npx + GITHUB_PERSONAL_ACCESS_TOKEN env | present in computed | (no diff — already platform=linux) | Already in `settings.linux.json`. No action. |
| `statusLine.command` | `bash "/home/christian/.claude/hooks/statusline.sh"` | _absent_ from computed | **override** (or **platform**) | Currently absent from computed output. Hardcoded `/home/christian/` path is stale. **Flagged for user review** — promote to linux platform with `$HOME/.claude/hooks/statusline.sh` if user wants it cross-linux, otherwise drop. |
| `skipAutoPermissionPrompt` | `true` | `true` (already in base) | (no diff) | Already in base. |

## linuxbro (platform=linux)

Snapshot at `.attic/settings-pre-merge/linuxbro.json` (173 lines — superset of
superbro: same plugins, same MCPs, plus hooks).

| Path | Old (snapshot) | New (computed) | Decision | Reason |
|------|----------------|----------------|----------|--------|
| `effortLevel` | `"medium"` | `"high"` | **base** | Same as superbro. |
| `awaySummaryEnabled` | _absent_ | `false` | **base** | Same as superbro. |
| `enabledPlugins["ck@cavekit-marketplace"]` | _absent_ | `true` | **base** | Same as superbro. |
| `enabledPlugins["github@claude-plugins-official"]` | `true` | `false` | **base** | Same as superbro. |
| `extraKnownMarketplaces["cavekit-marketplace"]` | _absent_ | present | **base** | Same as superbro. |
| `spinnerVerbs` | _absent_ | present | **base** | Same as superbro. |
| `permissions.additionalDirectories[0]` | _absent_ | `"$HOME/dotfiles/.claude"` | **platform** (linux) | Same as superbro. |
| `hooks.Notification` | _absent_ | `[]` | **platform** (linux) | Same as superbro. |
| `hooks.PreToolUse[Bash].git-push-guard.sh` | `/home/christian/.claude/hooks/git-push-guard.sh` | `$HOME/.claude/hooks/git-push-guard.sh` | **platform** (linux) | Same command, path normalised to `$HOME`. Already in `settings.linux.json`. Pure value change, no decision beyond accepting `$HOME` form. |
| `hooks.PreToolUse[Bash].rtk-rewrite.sh` | `/home/christian/.claude/hooks/rtk-rewrite.sh` | `$HOME/.claude/hooks/rtk-rewrite.sh` | **platform** (linux) | Same — path normalisation. |
| `hooks.SessionStart.entroly-start.sh` | `/home/christian/.claude/hooks/entroly-start.sh` (async) | `$HOME/.claude/hooks/entroly-start.sh` (async) | **platform** (linux) | Same — path normalisation. |
| `hooks.SessionStart.claude-session-check.sh` | `/home/christian/.claude/hooks/claude-session-check.sh` | _absent_ from computed | **drop** | Hook not present in current `settings.linux.json`. Per Task 7 audit findings (referenced from progress.md), this hook was either consolidated into entroly-start or retired. Drop. **Flagged for user review** — if the user still wants session-check, promote to linux platform; otherwise this confirms the drop. |
| `hooks.UserPromptSubmit.effort-classifier.sh` | `/home/christian/.claude/hooks/effort-classifier.sh` | `$HOME/.claude/hooks/effort-classifier.sh` (timeout 5) | **platform** (linux) | Same — path normalisation. Already in `settings.linux.json` with timeout. |
| `mcpServers.atlassian-akqa` | full block | _absent_ from computed | **override** | Same as superbro — per-host work creds. |
| `mcpServers.atlassian-fiskars` | full block | _absent_ from computed | **override** | Same as superbro. |
| `mcpServers.engram-personal` | ssh superbro + ENGRAM_DATA_DIR=/home/christian/.engram/personal | _absent_ from computed | **override** | Per-host MCP. linuxbro SSHes to superbro for engram (uses superbro as engram host) — that's a legitimate per-host wiring choice, must live in linuxbro override. |
| `mcpServers.engram-work` | ssh superbro + ENGRAM_DATA_DIR=/home/christian/.engram/work | _absent_ from computed | **override** | Same. |
| `mcpServers.github` | full block | present in computed | (no diff) | Already in `settings.linux.json`. |
| `statusLine.command` | `bash "/home/christian/.claude/hooks/statusline.sh"` | _absent_ from computed | **override** (or **platform**) | Same flagging as superbro — promote to linux platform with `$HOME` form or drop. |
| `skipAutoPermissionPrompt` | `true` | `true` | (no diff) | Already in base. |

## Summary

- Total diff rows (deduped across hosts): 19
- Mac: 0 diffs (already cut over in Task 14)
- linuxbro + superbro share the same diff set; counts below are unique decisions.

By decision:

- **base**: 6 — `effortLevel`, `awaySummaryEnabled`, `enabledPlugins.ck`, `enabledPlugins.github`, `extraKnownMarketplaces.cavekit-marketplace`, `spinnerVerbs`
- **platform** (linux): 7 — `permissions.additionalDirectories`, `hooks.Notification`, `hooks.PreToolUse[Bash].git-push-guard.sh`, `hooks.PreToolUse[Bash].rtk-rewrite.sh`, `hooks.SessionStart.entroly-start.sh`, `hooks.UserPromptSubmit.effort-classifier.sh`, `mcpServers.github`
- **override**: 4 — `mcpServers.atlassian-akqa`, `mcpServers.atlassian-fiskars`, `mcpServers.engram-personal`, `mcpServers.engram-work`
- **drop**: 1 — `hooks.SessionStart.claude-session-check.sh`
- **flagged for user review**: 2 — `statusLine.command` (promote vs drop), `claude-session-check.sh` (confirm drop)

### Notes / risk flags

1. **Engram MCPs for linuxbro** — snapshot has linuxbro SSHing back to superbro for engram. That's a deliberate per-host wiring (linuxbro doesn't run engram locally); preserve in linuxbro override.
2. **statusLine** — both linux hosts had a statusline hook with hardcoded `/home/christian/` paths. Currently absent from computed merge output. User should decide: promote to linux platform with `$HOME` form, or drop entirely if no longer used.
3. **claude-session-check.sh** — present only on linuxbro (not superbro). If still desired, must be added to linux platform or linuxbro override. Currently dropped by computed merge.
4. **Risk of credential leak**: atlassian-akqa and atlassian-fiskars MUST stay in override, never in platform layer. Confirmed — they are absent from `settings.linux.json` already.

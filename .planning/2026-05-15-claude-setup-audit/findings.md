# Findings — Claude Setup Audit (2026-05-15)

## Mac (akqamacbook) baseline

### Files
| File | Lines |
|---|---|
| `~/.claude/CLAUDE.md` | 216 |
| `~/dotfiles/.claude/RTK.md` | 29 |
| `~/dotfiles/.claude/agent-style/claude-code.md` | 54 |
| `~/dotfiles/.claude/agent-style/RULES.md` | **801** (imported via `@RULES.md`) |
| `~/.claude/settings.json` | 337 |
| `~/.claude/settings.local.json` | 11 |

**Biggest single token sink: `RULES.md` at 801 lines loaded every conversation start via `@` import.**

### Plugins (17, all enabled except github + remember)
- `frontend-design`, `superpowers`, `code-simplifier`, `claude-md-management`, `claude-code-setup`, `atlassian`, `shopify`, `liquid-skills`, `liquid-lsp`, `code-review`, `skill-creator` (from `claude-plugins-official`)
- `caveman`, `planning-with-files`, `plannotator`, `ck` (from external marketplaces)

### User-installed skills (~/.claude/skills)
caveman, find-skills, graphify, plannotator-{annotate,compound,last,review,setup-goal}, shopify-theme-development, vite, writing
(`skills.list` and `skills.server-headless.list` = config files, not skills)

### Hooks (7)
- `claude-session-check.sh`
- `effort-classifier.sh` (auto-effort hint per prompt)
- `entroly-start.sh`
- `git-push-guard.sh` (push whitelist enforcement)
- `rtk-rewrite.sh` (RTK token-killer hook)
- `statusline.sh`
- `tuna-notify.sh`

### MCP servers (`mcp-servers.list`, 14 active definitions)
Local: `github`, `lean-ctx`, `mcp-mermaid`, `tailwindcss`, `google-calendar`, `atlassian-fiskars`, `atlassian-akqa`
Tailscale-only: `engram-personal`, `engram-work`, `graphiti`, `mcp-dockhand`, `mcp-dockhand-linuxbro`, `docker-superbro`, `docker-linuxbro`

### Disconnected MCPs observed this session (~77 deferred tools went stale)
- `apple-mcp` (8 tools) — not in `mcp-servers.list`. Legacy registration?
- `engram-personal` / `engram-work` (19 + 19 tools) — disconnected mid-session despite being in list
- `plugin_atlassian_atlassian` (31 tools) — likely from `atlassian` plugin server

**Cost: even disconnected, their deferred-tool slots are listed in metadata until next session start.**

## superbro

- `~/.claude/CLAUDE.md`: 216 lines (matches Mac ✓)
- `~/.claude/settings.json`: 129 lines (drift from Mac's 337 — different `enabledPlugins`?)
- Plugins: caveman, claude-plugins-official, planning-with-files, plannotator
- **Missing**: `cavekit-marketplace` (no `/ck:*` skills on superbro)
- **Extra**: `plannotator-visual-explainer`, also `caveman` skill listed twice (plugin + user-skill)
- No `claude-code-warp` (mac-only, ok)

## linuxbro

- Reached via `ssh christian@100.100.1.100` (tailnet). Hostname-alias config (port 27789) blocks LAN — use tailnet IP.
- `~/.claude/CLAUDE.md`: 216 lines (matches Mac ✓)
- `~/.claude/settings.json`: **173 lines** (third distinct size: 337/129/173 across hosts)
- Plugins: caveman, claude-plugins-official, planning-with-files, plannotator — **same as superbro**, missing `cavekit-marketplace`
- Skills: matches superbro (incl. `plannotator-visual-explainer`)
- Hooks (6): claude-session-check, effort-classifier, entroly-start, git-push-guard, rtk-rewrite, statusline. **Missing `tuna-notify.sh`** (Mac-only?).

## monsterbro-wsl

- SSH auth fails with "Too many authentication failures" even with `IdentitiesOnly=yes -i specific_key -o IdentityAgent=none`. Probable cause: no authorized_keys entry for any local Mac key, or strict `MaxAuthTries`.
- Probe deferred to manual session. Not blocking Phase 2.

## Overlap matrix (skills doing the same job)

| Function | Candidates | Recommendation |
|---|---|---|
| Code review | `code-review` plugin, `superpowers:requesting-code-review`, `plannotator-review`, `caveman:caveman-review`, `/review`, `/security-review` | **Keep:** `plannotator-review` (interactive UI) for diffs, `caveman:caveman-review` for terse PR-style, `/security-review` for security-specific. **Drop trigger ambiguity**: pick one default for `.review` (already → plannotator-review). |
| Planning | `planning-with-files:plan`, `superpowers:writing-plans`, `EnterPlanMode`, `/ck:spec`, `superpowers:brainstorming` | **Keep all 3 lanes** as routed in CLAUDE.md (big/mid/component-spec). Already disambiguated. |
| Caveman | `caveman:caveman`, `caveman:caveman-{commit,review,help,stats}`, `ck:caveman` | **Keep:** plugin caveman primary. `ck:caveman` is scoped to spec-writes only (different purpose). No actual collision. |
| Memory | `engram-personal`, `engram-work`, `graphiti` | **Routed** in CLAUDE.md. Engram default, graphiti for relations. Risk: dual-write doubles cost when not needed. Refine rule. |
| Ctx read | `lean-ctx:ctx_read`, native `Read` | **Conflict**: lean-ctx instructions say "NEVER use Read" but system prompt + skills push native Read. Decide: native default, lean-ctx only for files >1000 lines or session compression. |

## Hook audit (resolved)
- `entroly-start.sh` — starts entroly proxy + auto-resyncs Claude config. **Keep.**
- `tuna-notify.sh` — dock bounce + Claude.app focus on Notification event. **Keep.** Mac-only.
- `claude-session-check.sh` — checks `~/.local-secrets` for required tokens at session start. **Keep.**
- `statusline.sh` — status line. **Keep.**
- `effort-classifier.sh`, `git-push-guard.sh`, `rtk-rewrite.sh` — all active. **Keep.**

## apple-mcp status (resolved)
- Registered via `claude mcp add` (not in `mcp-servers.list`). Currently `✓ Connected`. Provides Calendar/Mail/Notes/Messages/Maps/Contacts/Reminders/webSearch tools.
- Disconnects mid-session intermittently (saw it drop in this session). Source: `bunx -y @dhravya/apple-mcp@latest`.
- **Decision:** keep registered (calendar+contacts useful via worklog), but accept flakiness. Action: move into `mcp-servers.list` for parity across hosts (currently only on Mac via local `claude mcp add`).

## RTK usage (resolved)
RTK pays off significantly:
- `rtk find` = 3.5M tokens saved (69.4% reduction)
- `rtk read` = 166K saved (lots of small reads)
- `rtk grep` = 52K saved
- `rtk curl` heavy savings on bulk downloads
**Decision:** keep RTK. Token win confirmed.

## Classification (Phase 2)

### Plugins (Mac, 17 enabled)
| Plugin | Use frequency | Keep? |
|---|---|---|
| `caveman` | every session (default mode) | ✓ KEEP |
| `superpowers` | TDD, brainstorming, planning | ✓ KEEP |
| `planning-with-files` | multi-step projects | ✓ KEEP |
| `plannotator` | every review/plan exit | ✓ KEEP |
| `ck` (cavekit) | spec-driven work | ✓ KEEP |
| `frontend-design` | UI work | ✓ KEEP |
| `atlassian` | Jira/Confluence | ✓ KEEP |
| `shopify` | work projects | ✓ KEEP |
| `liquid-skills` | work projects | ✓ KEEP |
| `liquid-lsp` | work projects | ✓ KEEP (LSP only loads in liquid contexts) |
| `claude-md-management` | occasional | ✓ KEEP |
| `claude-code-setup` | first-time setup only | ⚠ MAYBE DISABLE (one-time use) |
| `skill-creator` | when authoring skills | ⚠ MAYBE DISABLE (rare) |
| `code-simplifier` | overlaps `superpowers` + `caveman:simplify` | ✗ DROP |
| `code-review` | overlaps `plannotator-review`, `caveman:caveman-review` | ✗ DROP (most reviews go through plannotator) |
| `github` | already disabled | — |
| `remember` | already disabled | — |

### User skills (~/.claude/skills)
| Skill | Status |
|---|---|
| `caveman` | ✓ KEEP (also plugin — dedupe by removing user copy if plugin covers) |
| `find-skills` | ✓ KEEP |
| `graphify` | ✓ KEEP |
| `writing` | ✓ KEEP |
| `vite` | ⚠ MOVE — should be per-project, not global |
| `shopify-theme-development` | ⚠ CHECK — overlaps `shopify` plugin? |
| `plannotator-{annotate,compound,last,review,setup-goal}` | ✗ DROP DUPES — plugin provides these |

### MCP servers
| Server | Decision |
|---|---|
| `github` | ✓ KEEP |
| `lean-ctx` | ⚠ SCOPE DOWN — make on-demand (large files only), don't override Read globally |
| `mcp-mermaid` | ✓ KEEP (occasional) |
| `tailwindcss` | ✓ KEEP |
| `google-calendar` | ✓ KEEP |
| `atlassian-fiskars` | ✓ KEEP |
| `atlassian-akqa` | ✓ KEEP |
| `engram-personal` | ✓ KEEP |
| `engram-work` | ✓ KEEP |
| `graphiti` | ✓ KEEP |
| `mcp-dockhand` | ✓ KEEP (UI-style stack mgmt) |
| `mcp-dockhand-linuxbro` | ✓ KEEP |
| `docker-superbro` | ✓ KEEP (raw docker via SSH, different use case from dockhand) |
| `docker-linuxbro` | ✓ KEEP |
| `apple-mcp` | ✓ KEEP (move to `mcp-servers.list` for cross-host parity) |
| `shopify-dev` (via plugin) | ✓ KEEP |
| `plugin_atlassian_atlassian` (via plugin) | ✓ KEEP (this is the `atlassian` plugin's MCP) |

### Hooks
All 7 hooks → **KEEP** (confirmed purposes above).

## Phase 2 Summary
- **Drop:** `code-simplifier`, `code-review`, duplicate `plannotator-*` user skills.
- **Maybe disable:** `claude-code-setup`, `skill-creator`.
- **Scope down:** `lean-ctx` (decision in Phase 3).
- **Move:** `apple-mcp` registration into `mcp-servers.list`.
- **Reconcile:** add `cavekit-marketplace` on superbro/linuxbro.
- **Investigate:** `vite` global skill, `shopify-theme-development` vs `shopify` plugin overlap.

## Architecture finding (Phase 6) — `settings.local.json` is per-host

- `settings.local.json` is **gitignored** (`.gitignore:63`). Each host has its own copy on disk.
- `settings.base.json` is tracked but **runtime ignores it** — nothing reads `base` directly. It's a template only.
- `~/.claude/settings.json` symlinks to `dotfiles/.claude/settings.local.json` on every host.
- Result: edits to `settings.base.json` do not propagate; must edit each host's `settings.local.json` separately.

**Today's fix:** SSH-applied same plugin-disable sed to superbro + linuxbro `settings.local.json`. Backups: `settings.local.json.bak.2026-05-15`.

**Next-session followup (not part of this audit):**
- Either remove `settings.local.json` from `.gitignore` and track one canonical copy, or
- Add a bootstrap step that overlays `settings.base.json` onto per-host `settings.local.json` keeping host-specific keys (Mac hook paths, etc.) intact.

## Token estimate (rough — confirm via `rtk gain` post-cleanup)

| Item | Approx tokens loaded per session |
|---|---|
| `RULES.md` (801 lines) | ~6,500 |
| `CLAUDE.md` (216 lines) | ~1,800 |
| Skill descriptions (~80 skills × ~30 tokens metadata) | ~2,400 |
| MCP tool descriptions (active core tools only) | ~3,000 |
| MCP deferred-tool listing (`MEMORY.md` etc) | ~1,500 |
| **Subtotal session start overhead** | **~15,000 tokens** before first user message |

Targets after cleanup:
- Compress `CLAUDE.md` → ~120 lines (~1,000 tokens, -800) — **SKIPPED** (structured tables, low gain)
- Compress or trim `RULES.md` → embed rule names only; full bodies on demand (~200 tokens, -6,300) — **DONE** via dropping `@RULES.md` import
- Disable apple-mcp registration, fix engram reconnect, remove dupes (-1,500) — **PARTIAL** (4 plugins disabled, 5 user-skill dupes removed; apple-mcp kept but moved to list)

## Achieved (theoretical, confirm next session)
| Win | Estimated tokens saved |
|---|---|
| Drop `@RULES.md` import (801 lines no longer auto-loaded) | ~6,300 |
| Disable 4 plugins (skill descriptions stop loading): code-simplifier, claude-code-setup, code-review, skill-creator | ~600 |
| Remove 5 duplicate plannotator user-skills + vite global | ~400 |
| Memory dual-write rule tightened (fewer save calls per session) | ~200 (runtime, not startup) |
| **Total estimated startup savings** | **~7,300 tokens** |

**Next-session verification:**
- Open fresh Claude Code session in any dir
- Check session-start tool/skill list — should be smaller
- Compare via `rtk gain` history once tokens flow

**Expected delta:** ~7,300 tok/session at start. Target was 8,500. Gap = ~1,200 — left on the table:
- CLAUDE.md compression (skipped — keep structured for readability)
- lean-ctx description (only saves IF Claude follows new routing rules and doesn't reach for it on small files)

## Drift table (Mac → other hosts)

| Item | Mac | superbro | linuxbro | wsl |
|---|---|---|---|---|
| CLAUDE.md | 216 | 216 ✓ | 216 ✓ | ? |
| settings.json | 337 | 129 ⚠ | 173 ⚠ | ? |
| `cavekit-marketplace` | ✓ | ✗ | ✗ | ? |
| `plannotator-visual-explainer` | ✗ | ✓ | ✓ | ? |
| `tuna-notify.sh` hook | ✓ | ? | ✗ | ? |
| Device snapshot file | ✓ | ✗ | ✗ | ✗ |

**Action:** generate device snapshots for all hosts at session start; sync settings via stow.

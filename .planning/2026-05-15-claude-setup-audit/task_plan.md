# Task Plan — Claude Setup Audit + Optimization

## Goal
Cut per-session Claude Code token overhead by ~50% while preserving caveman default, cavekit, planning-with-files, plannotator, Tailscale-gated MCPs, and Engram + Graphiti memory routing.

## Current Phase
Phase 7 (Verify token savings) — pending

## Constraints
- No customer/client repo touches (per push-whitelist policy).
- All changes go through dotfiles repo so they sync via stow.
- No `Co-Authored-By: Claude` trailer in commits.
- Commit per phase for rollback safety.

## Phases

### Phase 1 — Inventory
**Status:** complete (wsl deferred — auth broken, not blocking)
- [x] Mac plugin/skill/hook/MCP list → `findings.md`
- [x] superbro probe via tailnet
- [x] linuxbro probe via `christian@100.100.1.100`
- [ ] monsterbro-wsl probe — SSH auth fails ("too many auth failures") even w/ IdentitiesOnly. Defer to manual fix.

### Phase 2 — Classify overlaps + dead items
**Status:** complete
- [x] Per skill/plugin: tag keep / merge / drop → `findings.md` Phase 2 section
- [x] Identified apple-mcp source: `claude mcp add` registration (not list)
- [x] Hooks audited — all 7 confirmed in active use
- [x] Drop list: `code-simplifier`, `code-review`, duplicate `plannotator-*` user skills
- [x] Maybe-disable: `claude-code-setup`, `skill-creator`
- [x] Investigate items: `vite` global skill, `shopify-theme-development` overlap

### Phase 3 — Decide canonical lanes
**Status:** complete (signed off by user 2026-05-15)
- [x] **Drop:** `code-simplifier`, `code-review` plugins
- [x] **Drop import:** `@RULES.md` from `agent-style/claude-code.md` (very yes)
- [x] **Disable:** `claude-code-setup`, `skill-creator` plugins
- [x] **Move:** `vite` skill from global → per-project only
- [x] **Lean-ctx routing** (override "NEVER use Read" default):
  - Native Read default
  - lean-ctx when: file ≥500 LOC, re-read in session, repeated codebase search, /clear resume, project map
- [x] **Review default:** `plannotator-review` for `.review`; caveman-review + security-review as named alternatives
- [x] **Memory rule:** engram-only unless relational; never dual-write flat facts

### Phase 4 — Trim plugins/MCPs/skills
**Status:** complete (2 commits: 3b0bd97, 97509c1)
- [x] Disable code-simplifier, claude-code-setup, code-review, skill-creator plugins
- [x] Add cavekit-marketplace to settings.base.json (cross-host parity)
- [x] Move apple-mcp into mcp-servers.list (was ad-hoc on Mac)
- [x] Move 5 duplicate plannotator-* + vite user skills to `.disabled-2026-05-15/`

### Phase 5 — Compress CLAUDE.md + RTK.md + RULES.md
**Status:** complete (folded into Phase 4 commit 3b0bd97)
- [x] Dropped `@RULES.md` import — biggest win, ~6,300 tok/session saved
- [SKIP] CLAUDE.md compression — already structured routing tables; caveman compression would hurt readability. Re-evaluate after Phase 7 if delta < target.
- [SKIP] RTK.md compression — only 29 lines, negligible win.

### Phase 6 — Sync cross-host
**Status:** complete (partial — wsl deferred + device snapshots deferred)
- [x] Pushed dotfiles master → pulled on superbro + linuxbro
- [x] Doctor checked: hooks symlinked OK on both Linux hosts
- [x] Discovered `settings.local.json` is gitignored per-host — applied plugin-disable sed via SSH on superbro + linuxbro with `.bak` rollback
- [DEFER] Add device-snapshot hook to Linux hosts (mac-only currently) — separate task
- [DEFER] Cavekit-marketplace install on superbro/linuxbro — needs settings.local.json schema overlay (see findings)
- [DEFER] monsterbro-wsl — SSH auth broken, separate task

### Phase 7 — Verify
**Status:** in_progress (full verification requires fresh session)
- [x] `rtk gain` baseline captured pre-cleanup (in findings.md)
- [x] Theoretical post-cleanup estimate: ~7,300 tok/session saved (vs ~8,500 target — gap explained in findings)
- [ ] Fresh Claude Code session → confirm reduced session-start token count (user action)
- [ ] If delta < ~6,000, revisit Phase 8 for deeper trim (CLAUDE.md compression, lean-ctx audit)

## Decisions Made
| Decision | Rationale |
|---|---|
| Isolated plan dir under `.planning/2026-05-15-claude-setup-audit/` | dotfiles repo public-ish; don't want plan churn in commits |
| Keep all 3 planning lanes (planning-with-files / EnterPlanMode / ck:spec) | non-overlapping by scope per CLAUDE.md routing |
| Keep caveman + ck:caveman both | different scope (global mode vs SPEC.md-only encoding) |
| Drop `code-simplifier` + `code-review` plugins | user confirmed; overlap w/ caveman + plannotator |
| Drop `@RULES.md` import (801 lines) | biggest token win; load on demand via Read when writing prose |
| Disable `claude-code-setup` + `skill-creator` | not used |
| Move `vite` skill to per-project | not relevant to all projects |
| Lean-ctx: routing table in CLAUDE.md overrides "NEVER use Read" | mixed signal currently; explicit rules for when each is cheaper |
| Memory: engram-only default; dual-write only when relational | cuts ~30% of save calls |

## Errors Encountered
| Error | Phase | Resolution |
|---|---|---|
| linuxbro SSH timeout | 1 | retry via tailnet 100.x IP instead of LAN |
| monsterbro-wsl host key changed | 1 | `ssh-keygen -R monsterbro-wsl` then re-accept |

# Progress Log — Claude Setup Audit

## Session: 2026-05-15

### Current Status
- **Phase:** 1 — Inventory (in_progress)
- **Started:** 2026-05-15

### Actions Taken
- Initialized planning dir under `.planning/2026-05-15-claude-setup-audit/`.
- Captured Mac inventory: 17 plugins enabled, ~30 MCP defs, 7 hooks, 14 active user skills.
- Identified agent-style `RULES.md` (801 lines) as biggest single token sink.
- Partial superbro probe: same CLAUDE.md size, drift in `settings.json`, missing cavekit, extra plannotator-visual-explainer.
- linuxbro / monsterbro-wsl probes deferred (SSH issues, see errors table).
- Sized 4 disconnected MCPs (apple-mcp + engram × 2 + atlassian-plugin) = ~77 stale deferred-tool slots.
- Rough overhead estimate: ~15,000 tok/session at session start. Target after cleanup: ~6,500 (-55%).

### Test Results
| Test | Expected | Actual | Status |
|---|---|---|---|
| SSH superbro | reachable | OK | ✓ |
| SSH linuxbro | reachable | timeout port 27789 | ✗ |
| SSH monsterbro-wsl | reachable | host key changed | ✗ |
| Tailscale MagicDNS resolve | works system-wide | resolver missing nameserver (separate task, fixed earlier) | ⚠ |

### Errors
| Error | Resolution |
|---|---|
| linuxbro ssh timeout | Retry via 100.x tailnet IP. Phase 1. |
| monsterbro-wsl host key | `ssh-keygen -R monsterbro-wsl`. Phase 1. |

### Next Session

**START HERE:** Run `/superpowers:brainstorming` on platform-specific `settings.local.json` architecture.

Problem: drift between Mac / superbro / linuxbro / monsterbro-wsl `settings.local.json` files because each has host-specific bits (hook paths `/Users/...` vs `/home/...`, MCP availability, plugin set). Currently the file is gitignored per-host — manual edits don't propagate. Today's audit applied 4 plugin disables via SSH sed; not sustainable.

Brainstorm scope:
- Platform tiers: `darwin` (Mac), `linux` (superbro, linuxbro), `wsl` (monsterbro-wsl).
- What should be shared (plugin enablement, memory rules, permissions) vs platform-specific (hook paths, MCPs like apple-mcp, hostname-derived ENV).
- Possible mechanisms: settings.base.json + platform fragments merged at bootstrap; per-platform settings.{darwin,linux,wsl}.json; jq-driven overlay script; or commit settings.local.json and use env-var substitution at session start.

Other deferred items (Phase 8):
- Verify token savings via fresh-session metadata check.
- Compress CLAUDE.md routing tables further (if still over budget).
- Filter MCP descriptions via startup hook (cut lean-ctx "NEVER use Read" noise without modifying MCP itself).
- Add device-snapshot SessionStart hook to Linux hosts.
- Fix monsterbro-wsl SSH auth ("too many authentication failures" — no authorized_keys match for any local key).

### Session 1 close — Phases 1-7 done
- 3 commits on `master` (`3b0bd97`, `97509c1`, settings.local.json applied via SSH not committed since gitignored).
- Plugin disables propagated to Mac + superbro + linuxbro.
- Estimated savings: ~7,300 tok/session start.
- Backups: `~/.claude/skills/.disabled-2026-05-15/` (skill copies); `settings.local.json.bak.2026-05-15` (superbro + linuxbro).
- Audit dir: `.planning/2026-05-15-claude-setup-audit/`.

## Session: 2026-05-17 — MCP reliability follow-up

### Status
- **Phase:** 7 closed (token savings verified + executed Phase 8 carryover items)

### What landed
- **Skill audit applied** (Q1+Q2+Q3+Q5 from owned-skills review):
  - 17 stencil/diagram skills got `user-invocable: false` + Markdown-Viewer marketing boilerplate stripped (~330 tok saved per session).
  - `security` → `security-diagram`, `disable-model-invocation: true` (kills collision with vendor `security-review`).
  - `_plantuml-base/REFERENCE.md` extracted as shared base for 6 stencil skills (UML/ArchiMate/BPMN/data-analytics/network/security-diagram).
  - User-owned `caveman` skill retired → vendor `caveman:*` plugin (strict superset). Parked at `~/.agents/.retired-skills/`.
  - Global `shopify-theme-development` split into 4 project-local skills under `/Projects/Shopify/Fiskars/.claude/skills/` (`stellar-shopify-theme-development` umbrella + `stellar-multi-store-arch` + `stellar-schema-system` + `stellar-asset-pipeline`).
  - Commit: `ce7a98c refactor(claude-skills): retire user-owned caveman + move shopify-theme to project`.

- **MCP reliability audit** (7-day log analysis):
  - Worst offenders surfaced: mcp-dockhand 5136 errors, graphiti 498, 13 × claude-ai-* connectors ~228 each.
  - Root causes: HTTP idle reaper (dockhand), cloud-auth-loop (unauth connectors), SSH no-keepalive (docker-superbro/linuxbro).
  - **Fixes applied:**
    - `deniedMcpServers` in `settings.base.json` blocks 17 unauthenticated `claude.ai *` cloud connectors → ~3000 errors/7d eliminated.
    - SSH ControlMaster + ControlPersist 10m + ServerAliveCountMax 6 + TCPKeepAlive yes for superbro + linuxbro (dotfiles install script + live `~/.ssh/config`).
    - Patched own fork `cbrostrom/mcp-dockhand`: env-configurable `SESSION_INACTIVITY_TIMEOUT_MS` (default 4h, was 30m hardcoded). PRs: cbrostrom/mcp-dockhand#1 + upstream strausmann/mcp-dockhand#65. 176/176 tests passing.
  - Commit: `ff11f90 feat(claude): mcp reliability fixes + mcp-doctor skill`.

- **New skill `mcp-doctor`** — SOLID composable diagnostic:
  - Pipeline: `audit-logs.py | classify.py | inspect-mcp.py | save-to-brain.py`.
  - 5 root-cause categories mapped to fixes in `references/fix-playbook.md`.
  - Mirrors findings to brain (Engram + Graphiti).
  - Pattern: add new category = append to playbook + one line in classifier. No script-coupling refactor.

- **Brain saved:**
  - Engram id 205, topic `bugs/mcp-dockhand-session-reaper`.
  - Graphiti episode `mcp-dockhand session reaper bug + fix`, group `claude-code`.

- **Side fix** (unrelated): Danish keyboard Option-glyphs in ghostty + zsh quote-line bind removal. Commit: `ffb0cd0`.

### Test Results
| Test | Expected | Actual | Status |
|---|---|---|---|
| Skill audit applied | 12 skills frontmatter updated | 12 applied | ✓ |
| Caveman retired | Symlink + skills.list cleaned, dir parked | Done | ✓ |
| stellar-shopify project skills created | 4 SKILL.md under Fiskars/.claude/skills/ | Done | ✓ |
| `ssh -G superbro` | `controlmaster auto`, `serveralivecountmax 6` | Confirmed | ✓ |
| `deniedMcpServers` in merged settings.json | 17 entries | Confirmed | ✓ |
| mcp-dockhand PR opened | cbrostrom + upstream | Both open | ✓ |
| mcp-doctor smoke test | Pipeline emits JSON per stage | Working | ✓ |
| Engram save | id returned | 205 | ✓ |
| Graphiti episode queued | claude-code group | Queued | ✓ |

### Deferred / next
1. **Merge cbrostrom/mcp-dockhand#1** → wait for release.yml to publish new image → set `SESSION_INACTIVITY_TIMEOUT_MS=14400000` in superbro `docker-compose.yml` → restart. Expected: -90% on dockhand errors.
2. **Phase 8 carryover still open:**
   - Filter MCP descriptions via startup hook (lean-ctx "NEVER use Read" noise).
   - Add device-snapshot SessionStart hook to Linux hosts.
   - Fix monsterbro-wsl SSH auth.
3. **One-week observation window**: re-run `mcp-doctor` audit on 2026-05-24 to confirm error reductions vs current 7d baseline (5136 → ?, 498 → ?, ~3000 cloud-auth → 0).
4. **Vendor liquid-skills** installation into Fiskars project (user flagged for later in Q4 split).

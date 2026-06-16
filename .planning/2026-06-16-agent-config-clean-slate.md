---
created: 2026-06-16
updated: 2026-06-16
area: [meta, dev]
type: plan
status: active
tags: [dotfiles, cursor, claude-code, brain, agents-md, rules, skills, clean-slate]
repo: dotfiles
vault_target: Plans/Active/2026-06-16-agent-config-clean-slate.md
supersedes: Plans/Active/2026-06-16-lean-agent-stack-alignment.md
---

# Plan: Agent Config Clean Slate (Cursor + CC alignment)

_Revision after Cursor session 2026-06-16. User locked: plugin purge, no cavecrew, English-only default._

## Goal

One agnostic agent stack: vault brain for memory, dotfiles for policy, thin per-tool adapters. Strip Cursor plugin bloat. No duplicate rules. English output unless user asks for Danish.

## Locked decisions (this session)

| Topic | Decision |
|---|---|
| Cursor plugins | **Remove all** — clean slate |
| Subagents | **None** — no cavecrew, no ce-* reviewers |
| Language | **English default** — Danish only on explicit request |
| Brain | Vault `Brains/<slug>/` + `brain` CLI — unchanged |
| MCP sync | `agent-core.json` → `agent-core-sync.sh` — keep |
| Skills | `dotfiles/.claude/skills/` + `~/.agents/skills/` only |
| Prior plan | `Plans/Active/2026-06-16-lean-agent-stack-alignment` — MCP/CLAUDE slim phases still valid |

---

## Rules format: AGENTS.md vs `.cursor/rules/*.mdc` — grilled

### AGENTS.md

**Pros**
- Human-readable — one linear file; Obsidian/git diff friendly
- Tool-agnostic — emerging standard (Cursor, Copilot, Windsurf)
- Matches CLAUDE.md mental model — shared via `@` imports
- Single PR surface — reviewers see full policy delta
- Portable across repos — no per-rule YAML
- Low Cursor UI coupling — not tied to rules picker UX

**Cons**
- Cursor second-class vs `.mdc` — less documented; may miss future Cursor-only features
- No native file-scoped rules — can't `globs: **/*.liquid` without prose hacks
- Token risk if large and always injected — same as fat CLAUDE.md today
- No per-section UI toggle — edit file to disable one rule
- Duplication trap vs CLAUDE.md unless shared chunks live in `agent-style/`
- `brain setup --agent=cursor` still points at `.cursorrules` — needs patch

### `.cursor/rules/*.mdc`

**Pros**
- Cursor-native — `alwaysApply`, `globs`, `description` first-class
- Scoped injection — Shopify rules only on Liquid files
- Composable — enable/disable per file in UI
- "Apply intelligently" — token savings (model may skip — trade-off)
- create-rule skill assumes this format

**Cons**
- Hard to read holistically — policy scattered across N files
- Cursor-only — Claude Code ignores `.mdc`
- Frontmatter footguns — silent non-load if misconfigured
- Proliferation drift — you already duplicated CLAUDE.md into `rules.md`
- Multi-file git noise
- Doesn't solve CC — still need parallel tree

### Hybrid (recommended)

| Layer | File | Role |
|---|---|---|
| Shared SoT | `dotfiles/AGENTS.md` | Readable policy: brain, tools, English, push guard, dispatch pointers |
| CC adapter | `.claude/CLAUDE.md` | Thin: `@AGENTS.md` + CC-only (hooks, doctor, settings-arch) |
| Cursor adapter | `.cursor/rules/core.mdc` | `alwaysApply: true`, ≤15 lines, points to AGENTS.md + brain load |
| Scoped (later) | `.cursor/rules/shopify.mdc` | Only if glob-scoped rules needed |

**Why hybrid:** readable `AGENTS.md` for you; tiny `.mdc` for Cursor native path; no 150-line cloud rules; CC + Cursor share one core.

**Phase 0 verify:** Cursor agent follows AGENTS.md when `.mdc` only points at it. If not → inline minimal alwaysApply body + explicit "Read AGENTS.md before acting."

---

## Target architecture

```
dotfiles/
├── AGENTS.md                 # human SoT (NEW)
├── .claude/CLAUDE.md         # thin → @AGENTS.md
├── .cursor/rules/core.mdc    # thin Cursor adapter
├── .claude/skills/           # custom skills
├── .claude/agent-core.json   # model + MCP
└── scripts/brain             # memory CLI

~/.agents/skills/             # npx-installed payloads
~/.claude/skills/             # symlinks
~/.cursor/                    # runtime — plugins purged, hooks patched
~/Vaults/Brain/Brains/<slug>/ # runtime memory
```

**Explicitly removed:** all Cursor plugins, `~/.cursor/agents/`, cavecrew, `.cursor/rules.md`, `.cursorrules`.

---

## Phase 0 — Cursor clean slate (you, UI)

- [ ] Rules: empty ✓
- [ ] Plugins: uninstall all
- [ ] MCP: github + active `DOTFILES_WORKFLOWS` overlays only
- [ ] Restart Cursor
- [ ] Confirm: no ce-* tools/skills in new chat
- [ ] Optional: `rm -rf ~/.cursor/plugins/cache/*` after uninstall

## Phase 1 — AGENTS.md + adapters (agent)

- [ ] Create `AGENTS.md` — brain protocol, English default, advisor stance (short), native tools, push guard, planning thresholds
- [ ] Create `.cursor/rules/core.mdc` — thin pointer
- [ ] Slim `CLAUDE.md` → `@AGENTS.md` + CC-only sections
- [ ] Delete `.cursor/rules.md`
- [ ] Patch `scripts/brain`: `AGENT_FILES["cursor"]` → `AGENTS.md`; English-only in instructions

## Phase 2 — Cursor brain parity (agent)

- [ ] `~/.cursor/hooks.json` sessionStart → `bash '$HOME/.claude/hooks/brain-load.sh'`
- [ ] Verify: session surfaces `Brains/dotfiles/current` + active `next.md`

## Phase 3 — Skills (agent)

- [ ] Restore `.claude/skills/skills.list`
- [ ] Audit `~/.agents/skills/` — drop unused
- [ ] `modules/skills/install.sh` + `doctor.sh --fix`

## Phase 4 — Carry forward (separate session)

From lean-agent-stack plan:
- [ ] Remove lean-ctx + headroom MCP
- [ ] CLAUDE.md → `dispatch/` split
- [ ] MCP cull commit

## Phase 5 — Optional

- [ ] `agent-core.json` → `"policy_file": "AGENTS.md"`, `"subagents": false`

---

## Execution order

```
Phase 0  UI plugin purge + restart        ← YOU
Phase 1  AGENTS.md + adapters             ← agent
Phase 2  brain-load hook                  ← agent
Phase 3  skills.list                      ← agent
Phase 4  MCP/CLAUDE slim                  ← later
```

## Out of scope

- Custom subagents
- Plugin re-install without explicit opt-in
- RTK for Cursor
- Danish default in rules

## Pickup prompt

> Execute Phase 1–3 from agent-config-clean-slate plan. Phase 0 done.

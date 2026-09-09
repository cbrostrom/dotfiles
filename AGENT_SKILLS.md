# Agent Skills Inventory

One shared layer. All agents read from `.agents/skills/` → `~/.agents/skills/`.
Cursor reads via `~/.cursor/skills`.

## Shared Skills (17)

| Skill | Use |
|---|---|
| `code-cleaner` | Audit code health with aislop + fallow. Never fixes without permission. |
| `codebase` | Read CODEBASE.md and map the task to the 2–3 files worth reading next. |
| `codebase-memory` | Query codebase knowledge graph: callers, deps, dead code, impact. |
| `dotfiles` | Architecture + implementation guide for this repo. Approval before edits. |
| `dotfiles-update` | Local update + propagate to LinuxBro/SuperBro. Triggered by `/dotfiles`. |
| `fallow` | JS/TS unused code, duplication, circular deps, complexity, PR risk. |
| `higgins` | Vault protocol: search/load/current/next/gotcha. Prefer search over load. |
| `orca-cli` | Orca worktrees, terminals, artifacts, skill sharing. |
| `pi` | PI daily-driver reference: scoped models, MCP, hooks, subagents. |
| `release-notes` | Changelog from repo generator or git range + templates. |
| `shopify` | Shopify platform knowledge. MCP-first verification. |
| `sparring` | Adversarial ideation partner. Triggered by `/sparring`. |
| `systematic-debugging` | Evidence-first debugging before proposing fixes. |
| `tool-restraint` | Fewer MCP servers = better agent performance. |
| `unslop` | Humanize / strip AI-tell writing. |
| `verification-before-completion` | Evidence before claiming done. |
| `writing` | Draft and revise prose for external readers. |

## Cursor Built-Ins (`~/.cursor/skills-cursor/`)

Do not edit — Cursor owns and re-syncs this directory.

## Promotion Rule

Cross-agent workflows go in `.agents/skills/<name>/SKILL.md` — tool-neutral.
Harness glue stays in adapters (`.cursor/`, `.config/pi/`, etc.).

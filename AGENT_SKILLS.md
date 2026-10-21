# Agent Skills Inventory

One shared layer. GNU Stow deploys `stow/agents/.agents/skills/` to `~/.agents/skills/`.
Paseo runs Pi only; workers see the allowlist in `scripts/pi-paseo` (`PASEO_SKILLS`).

## Auto-invocable

| Skill | Use |
|---|---|
| `call` | Message a Paseo agent or pi-peer session. |
| `codebase` | Read CODEBASE.md and map the task to the 2-3 files worth reading next. |
| `commit` | Chunked conventional commits, with push and PR variants. |
| `dockhand` | Docker stacks on LinuxBro/SuperBro via Dockhand MCP only. |
| `fallow` | JS/TS unused code, duplication, circular deps, complexity, PR risk. |
| `higgins` | Vault protocol: search/load/current/next/gotcha. Prefer search over load. |
| `paseo`, `paseo-plugin`, `paseo-handoff` | Paseo CLI reference, plugin building, handoff. |
| `shopify` | Shopify platform knowledge. MCP-first verification. |
| `systematic-debugging` | Evidence-first debugging before proposing fixes. |
| `verification-before-completion` | Evidence before claiming done. |
| `writing` | Draft and revise prose for external readers. |
| `scout` | Read-only research subagent with guardrails. |
| `atlassian-agent` | Read-only Jira/Confluence (external symlink). |

## Manual only (`disable-model-invocation: true`)

| Skill | Use |
|---|---|
| `code-cleaner` | Audit code health with aislop + fallow. Never fixes without permission. |
| `codebase-memory` | Query codebase knowledge graph: callers, deps, dead code, impact. |
| `dotfiles`, `dotfiles-update` | Architecture guide for this repo; local update and propagate. |
| `pi` | Pi daily-driver reference, including MCP and tool restraint, capability map. |

Pi-only (`~/.pi/agent/skills/`): `creatorskill`, `lfg`, `rundown`, `paseo/`.

## Promotion Rule

Cross-agent workflows go in `stow/agents/.agents/skills/<name>/SKILL.md`.
Harness glue stays in `stow/pi/`, and focused `setup/` scripts.

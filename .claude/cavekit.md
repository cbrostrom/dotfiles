# Cavekit (component-level SPEC.md)

Use for single-component specs where invariants + bugs survive context resets.
planning-with-files = multi-file project plan. cavekit = single-component spec. Both coexist.

## Commands
| Command | Purpose |
|---|---|
| `/ck:spec` | Sole mutator. Write/amend `SPEC.md` (§G goal, §C constraints, §I interfaces, §V invariants, §T tasks, §B bugs) |
| `/ck:build` | Read `SPEC.md`, plan, execute. Test fail → auto-backprop §B + new §V invariant |
| `/ck:check` | Read-only drift report: flag code violations of §V/§I/§T |

## Backprop mirror (MANDATORY on §B/§V write)
1. `mem_save` on active Engram — topic key `bugs/{component}`, body = §B entry + §V invariant verbatim
2. Graphiti `add_memory` — links bug class → component node + commit SHA. Group id `claude-code`

Reason: SPEC.md per-repo; Engram+Graphiti cross-session/cross-project. No mirror = lessons siloed.

## Drift check before commit
Repo contains SPEC.md → run `/ck:check` before `git commit`. Surface drift, ask before staging.
No commit through unresolved §V violations without explicit user override.

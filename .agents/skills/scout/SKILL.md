---
name: scout
description: "Evaluate new tools, projects, formats, optimizations, research, or thought experiments against Christian's full agent setup before adopting. Forces primary-source research, setup-wide overlap analysis, and a hard adopt/borrow/reject verdict. Triggers: scout, .scout, evaluate X for my setup, look at this project, is X worth borrowing, new memory ideas, workflow optimization, thought experiment."
---

# Scout

Evaluate outside ideas against the existing setup. Scout never adopts: it researches, tests the premise, and proposes. Approval stays with the user.

## Setup map

Route each candidate only through the relevant layers. Do not produce an empty checklist for unrelated layers.

- **Memory and context:** Higgins vault, context-mode, Deja, session captures, recap and digest flows.
- **Agent behavior:** `AGENTS.md`, shared and harness-specific skills, prompt templates, policies, and hooks.
- **Harnesses and models:** Pi, Cursor, Paseo, model routing, providers, and local execution boundaries.
- **Orchestration and tools:** Orca/Paseo workers, subagents, MCP servers, CLI surfaces, and tool-restraint policy.
- **Efficiency:** RTK, context budgets, retrieval strategy, latency, token use, and background maintenance.
- **Distribution and operations:** dotfiles modules, symlinks, platform overlays, machine propagation, observability, and rollback.

## Workflow

1. **Check history.** Search `~/Vaults/Higgins/AI/_ops/scout-rejections.md` for the candidate and its core idea. A rejected idea needs new evidence or a changed revisit condition before reconsideration.
2. **Frame the claim.** State what the candidate claims to improve and which setup layers it touches. For a thought experiment, state a falsifiable hypothesis and the cheapest useful test.
3. **Research primary sources.** Read the project documentation, repository, paper, or specification. Separate documented behavior from marketing and self-reported results. Use outside sources only when they add independent evidence.
4. **Map the fit.** Compare against the relevant setup layers. Report:
   - gap addressed;
   - overlap and estimated redundancy percentage;
   - compatibility and integration boundary;
   - evidence quality;
   - privacy/security exposure;
   - cost, latency, and maintenance burden;
   - reversibility and smallest safe experiment.
5. **Verdict.** Choose exactly one:
   - `adopt` — fills a demonstrated gap. Propose the smallest reversible implementation or pilot.
   - `borrow` — extract a ranked list of ideas. Map each to a concrete patch, test, or Higgins deposit.
   - `reject` — state why it does not beat the current setup. No fence-sitting.
6. **Act only after approval.**
   - `adopt`: present files, change intent, break risk, verification, and rollback; wait for approval.
   - `borrow`: propose patches or tests; use Higgins (`gotcha`/`current`) for durable knowledge deposits.
   - `reject`: append the rejection record below and stop.

## Output contract

Lead with the verdict. Then provide, in order:

1. **What it is** — core mechanism in ≤5 bullets.
2. **Fit** — affected setup layers, gap, and redundancy estimate.
3. **Keep / skip** — ranked ideas worth borrowing and parts not worth adopting.
4. **Next experiment** — one bounded, reversible test with a success condition, or no experiment for a clear rejection.

## Rejection log

Append to `~/Vaults/Higgins/AI/_ops/scout-rejections.md`. One block per rejection:

```markdown
## YYYY-MM-DD — <name> (<URL or source>)
- Claim: <one line>
- Verdict reason: <why rejected>
- Evidence: <primary sources checked>
- Would revisit if: <condition that would change the verdict>
```

The log is append-only. Direct append is allowed because `_ops/` is agent-operations territory where Higgins digest and janitor also write. Never directly edit project brain files (`current.md`, `gotchas.md`, `history/`).

## Hard rules

- Never adopt or edit the setup without explicit approval.
- Check overlap before enthusiasm.
- Prefer a small falsifiable experiment over installing a framework.
- Treat vendor benchmarks as self-reported until independently reproduced.
- Do not add a tool, MCP server, daemon, or nightly job when a convention or existing component solves the gap.
- Verdict is exactly `adopt`, `borrow`, or `reject`.
- Every rejection is logged.

## Examples

- **OKF Agent Memory:** `borrow` provenance/trust and staleness ideas; reject its duplicate CLI/MCP layer because Higgins already provides Markdown, FTS5, validation, and progressive disclosure.
- **SkillOpt:** `borrow` bounded skill edits, held-out validation, no-regression gates, and staged adoption. Do not install nightly optimization until one measurable, text-oriented skill has a representative evaluation set; transcript privacy, provider cost, and tool-free replay limit broad use.
- **Vector database for Higgins:** `reject` while local FTS5 meets retrieval needs; revisit if semantic misses are measured on a representative query set.

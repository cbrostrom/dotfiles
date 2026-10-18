---
name: paseo-handoff
description: Hand off the current task to another agent with full context. Use when the user says "handoff", "hand off", "hand this to", or wants to pass work to another agent.
user-invocable: true
---

# Handoff Skill

**User's arguments:** $ARGUMENTS

## Paseo (canonical): use Handover, not a homemade briefing

In Paseo Desktop / RPC agents, **do not** call `create_agent` with a hand-written wall of context unless Handover is unavailable.

Direct the user to:

- **Handover pill** on the composer, or
- **`/handover`** (optional focus text), or
- Command Center → **Handover**

Handover runs a scoped transcript summarizer, editable preview, artifact attachment, and optional **Save durable decisions to Higgins**. That is the supported session handoff path.

Only if the user cannot use the UI (headless-only session, broken plugins): fall back to **Launch** below and match the **Handover schema** sections.

## Higgins is not session handoff

Use Higgins for **durable** facts (`current`, `gotchas`, project brain), via Handover's optional checkbox, `/digest`, or `.remember`. Do not replace Handover with vault dumps or `higgins load` as a transcript substitute.

## Fallback launch (non-UI or emergency)

Read the **paseo** skill. Call `list_profiles` before choosing the receiving agent.

### Parsing arguments

1. **Agent profile** — explicit profile name first; otherwise choose the profile whose `notes` best match the work. Materialize into `create_agent` per the **paseo** skill.
2. **Isolation** — "in a worktree" / "worktree" → `create_workspace` with `isolation: "worktree"` and a short branch name from the task.
3. **Task description** — anything else the user said.

### Handover-aligned briefing (same fields as summary-fork summarizer JSON)

```
# Goal
[Imperative task description.]

# Current state
[What's done, what works, what doesn't.]

# Decisions and rationale
- [Decision — why]

# Files changed
- `path` — [what changed]

# Evidence and verification
- [commands run, test output, paths]

# Failed or rejected approaches
- [Approach] — [why abandoned]

# Constraints and preferences
- [Must-not / must-preserve]

# Open questions and blockers
- [Unknowns]

# Recommended next action
[Single concrete next step]
```

**Preserve task semantics.** Investigate-only → "DO NOT edit files." Fix → implement the fix. Refactor → refactor, not rewrite.

### Steps

1. Select the current workspace or `create_workspace` with requested isolation.
2. `create_agent` with `[Handoff] <task>` title, briefing as `initialPrompt`, and `workspaceId` when needed.
3. Tell the user the agent stays in the subagent track until they detach manually.

Do not wait or poll for completion. Detach is a user gesture only.

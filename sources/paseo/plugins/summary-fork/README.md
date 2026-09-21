# Handover (plugin id: summary-fork)

Paseo plugin: **Handover** — press the Handover pill (or `/handover <focus>`)
to hand the current agent's task to a fresh conversation.

## Flow

1. **Handover** pill opens a menu:
   - **Handover in a new tab** — new agent in the same workspace.
   - **Handover in a new workspace** — new `branch-off` worktree workspace (falls back to a plain directory workspace when the source checkout is not a git repo).
   - ⌘K "Handover" also opens the panel; `/handover <focus>` opens it with focus prefilled.
2. Pick target, scope (since last compaction / full / last N turns) and optional focus instructions.
3. **Generate handover summary** — a throwaway auto-archived summarizer agent (host-scoped model setting, default `opencode-go/glm-5.3-flash`) reads a bounded text-only transcript and returns a structured handoff. A stuck run is cut off after 4 minutes and shows a clear error.
4. Edit the preview.
5. Optional **Save durable decisions to Higgins** (off by default).
6. **Create handover** — the approved summary is
   - written to the daemon artifact copy under `~/.paseo/handoffs/` (7-day retention),
   - attached to the receiving agent (so a missing file never loses the handover),
   - referenced by path in the receiving agent's prompt.
7. The new agent opens automatically (new tab or new workspace). The source agent stays intact.

## Continuity rules

- The default scope **includes the latest completed compaction summary** — it is
  the context of everything before it, so dropping it lost all pre-compaction
  history.
- Receiving-agent model copying only applies to model-policy-approved models;
  otherwise the receiver starts on the Pi default and `model-policy-guard`
  reverts any blocked selection before a request is sent.

## Internal name

The plugin id and directory remain `summary-fork` for install-path stability;
every user-facing surface is named Handover.

## Install

```bash
paseo plugin install ~/dotfiles/.config/paseo/plugins/summary-fork
paseo plugin reload summary-fork
```

## Test

```bash
npm install
npm test
npm run typecheck
```

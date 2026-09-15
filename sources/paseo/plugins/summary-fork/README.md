# summary-fork

Paseo plugin that forks a chat into a fresh conversation — same workspace (new tab) or a new isolated workspace — using a model-generated, editable summary. No Paseo patching, no temporary files.

## Flow

1. **Fork** pill opens a menu:
   - **Fork in a new tab** — new agent in the same workspace (target pre-selected in the panel).
   - **Fork in a new workspace** — new `branch-off` worktree workspace (falls back to a plain directory workspace when the source checkout is not a git repo).
   - ⌘K "Fork with summary" also opens the panel.
2. Pick target: New tab / New workspace (pre-selected from the menu, changeable).
3. Pick scope: since last compaction (default) / full / last 10-25-50 turns.
3. Optional focus instructions.
4. **Generate summary** — a throwaway auto-archived summarizer agent (host-scoped model setting, default `opencode-go/glm-5.3-flash`) reads a bounded text-only transcript and returns a structured handoff.
5. Edit the preview.
6. Optional **Save durable decisions to Higgins** (off by default; decisions/gotchas/blockers only).
7. **Create fork** — new agent, same provider/model/mode/thinking, receiving only the summary as a persisted virtual text attachment (`contextKind: "fork-summary"`). The panel opens the new tab, or the new workspace.

## Token and cache discipline

- The source chat is never touched, so its prompt cache stays intact.
- Transcript is fetched once from the timeline RPC (max 3 pages), filtered to user/assistant text only (no tool results or reasoning), and hard-capped (default 120 KB, oldest turns trimmed first).
- The fork chat starts with only the summary attachment.
- The summarizer is one cheap-model pass; its agent auto-archives after the run.

## Settings

Settings → Plugins → summary-fork (host-scoped):

| Setting | Default |
| --- | --- |
| Summarizer model | `opencode-go/glm-5.3-flash` |
| Transcript byte cap | 120000 |

## Limits

This is a semantic fork, not Pi's exact JSONL branch copy. Use Pi's native `/fork` in a TUI when exact branch ancestry matters.

## Install

```bash
paseo plugin install ~/dotfiles/sources/paseo/plugins/summary-fork
paseo plugin reload summary-fork
```

## Test

```bash
cd ~/dotfiles/sources/paseo/plugins/summary-fork
npm install
npm test
npm run typecheck
```

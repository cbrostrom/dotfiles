# Timeline UI Design Spec

Version 1. Date 17-09-2026. Scope: the chat timeline inside Paseo workspaces, rendered by this plugin on top of the daemon's item model. Grounded in three verified sources:

1. The pi event stream (captured: `/tmp/pi-timeline-events.jsonl`, 116 events, one read + bash + answer turn).
2. Paseo's pi provider mapping (read from `app.asar`) and the `AgentTimelineItem` union in `@getpaseo/protocol/agent-types.d.ts`.
3. Runtime probes (17-09-2026): interleaved thinking/tool turns through the live daemon, compared against pi session JSONL.

---

## 1. Data contract (verified)

### 1.1 What the daemon emits as timeline items

| Item type | Shape | Source |
| --- | --- | --- |
| `user_message` | `text`, `messageId?`, `clientMessageId?` | user prompt / attachment |
| `assistant_message` | `text` (all text blocks concatenated), `messageId?` | streamed `text_delta` accumulation + `message_end` |
| `reasoning` | `text` | one item per thinking segment, chronological |
| `tool_call` | `callId`, `name`, `status: running\|completed\|failed\|canceled`, typed `detail` (shell/read/edit/write/search/fetch/worktree_setup/sub_agent/plain_text/plan/unknown) | `tool_execution_start/update/end` |
| `todo` | `items` | pi `todo` tool result |
| `error` / `notification` | message, level | failures, notices |
| `compaction` | `status: loading\|completed`, `trigger: auto\|manual`, `preTokens?` | compaction events |
| `plugin` | `pluginId`, `kind`, `version`, `data` | any plugin via RPC (lossless side door) |

### 1.2 Stream events the UI can react to

`thread_started`, `turn_started`, `turn_completed` (usage), `turn_failed` (error, code, diagnostic), `turn_canceled` (reason), `usage_updated`, `mode_changed`, `model_changed`, `thinking_option_changed`, `permission_requested`, `permission_resolved`.

### 1.3 Provider behaviors confirmed at runtime (do not re-litigate)

- **Order is preserved.** Each thinking block becomes its own `reasoning` item; text is concatenated; items appear in chronological block order around tool cards. The item model is flat per message but never reordered.
- **Transient thinking exists.** Cursor/gemini streams reasoning fragments that pi never persists (session JSONL showed 2 thinking blocks, timeline showed 5 reasoning items). The timeline is richer than the session file, not poorer.
- **Never arrives:** `branchSummary`, `queue_update`, `session_info_changed`, `entry_appended`, tool-call argument streaming (args only appear at `tool_execution_start`), `toolResult.details` (only what Paseo's detail mappers extract).
- **The split-probe log stays empty without an open client.** Transforms run in the browser only; any headless verification of client-side behavior needs a Paseo window.

### 1.4 Design consequences

- Trust item order. Do not attempt to reconstruct block interleaving inside one `assistant_message`.
- Session JSONL is not the source of truth for what a user saw; the daemon item stream is.
- Anything lossless and custom goes through `plugin` items, not through parsing agent prose.

---

## 2. Current inventory

| Item | Transformer | Renderer | Status |
| --- | --- | --- | --- |
| `assistant_message` | `attention-blocks` | `attention-message` v6 | Done: `→` cards, 6 accent variants, icons, copy, stable streaming, prose density |
| `assistant_message` (no blocks) | - | `markdown-message` v3 | Done |
| `user_message` | `call-message`, `peer-message` | `call-message`, `peer-message` v2 | Done |
| `reasoning` | `attention-reasoning` | `attention-reasoning` v2 | Done: collapsed / latest expanded / expanded |
| `tool_call` | `tool-call` | `tool-call` v2 | Done: 4 states, detail branches, live output, inline/card style, line-diff for edits |
| `compaction` | `compaction-line` | `compaction-line` v2 | Done: thin divider row |
| `error`, `notification`, `todo`, `permission_requested` | none | none | Gap: Paseo default rows. Designs in §4 |
| turn lifecycle (started/failed/canceled/retry) | none | none | Gap: no retry/cancel affordance. Design in §4.4 |
| `plugin` items | n/a | per-plugin | Door open, no designs yet |

---

## 3. Design per item type

### 3.1 Assistant messages

- One timeline row per assistant message. `→` blocks become cards inside that row (already shipped; keep "no explode-into-rows during streaming").
- A message with zero `→` blocks renders as the markdown prose card (v3).
- Mixed message: prose segments stay together with their cards in document order; the attention transformer already segments on `kind`.
- No `→` and no markdown structure, short text: single quiet card, no icon.
- Copy: keep two formats (markdown/plain) on every card and every fenced code block.

### 3.2 Reasoning

- Keep the four modes (collapsed, latest expanded, expanded, hidden). `hidden` (commit 1f00ac2) drops mid-answer reasoning entirely for users who never want reasoning rows.
- **Policy: transient reasoning cap.** Because cursor/gemini can emit more reasoning segments than pi persists, cap visible reasoning cards per assistant message at 3 in collapsed mode, older ones collapsing into a "+N earlier" stub. Prevents reasoning floods from dominating a turn that produced one short answer.
- Reasoning items that arrive with zero text (empty deltas) never render.

### 3.3 Tool calls

- Card by default, inline only for read-style glanceable results (setting already exists).
- State machine: running (spinner + live partial output, capped height, auto-scroll) → completed (collapsed to summary: command / path / diff / match count per detail type) → failed (red edge + expandable error) → canceled (muted row).
- Args never stream (provider limitation). Show name immediately; args fill in when `tool_execution_start` lands. Do not design for streaming args.
- `plain_text`/`unknown` fallback keeps the generic card; never fabricate detail types.
- `sub_agent` detail: render as nested progress row with `actions` list when present.

### 3.4 User messages

- Own prompts: plain, no card chrome (existing `call-message`).
- `peer-message` cards keep their distinct tint; peer origin must stay visually separate from agent output.

### 3.5 Compaction

- Single thin divider line: "Context compacted (manual | auto @ ~Nk tokens)". Loading state shows a pulse. No summary text in the row; the summary is in context, not for display.

### 3.6 Uncovered item types (new designs)

- **`error` item** → thin red-edged system row, full message text, copyable. One row per error, no grouping.
- **`notification`** (info/warning/error) → same row anatomy as error, tinted by level, icon per level.
- **`todo`** → compact checklist card: items with done/pending marks, one card per `todo` item update (replacement semantics, not append).
- **`permission_requested`** → the composer-adjacent permission card Paseo already owns; timeline-ui only ensures it is never styled as an attention card (exclude permission text from card detection).

---

## 4. Turn lifecycle affordances

- **`turn_failed`** → red system row with `error`, plus `code` and `diagnostic` behind a "details" toggle.
- **`turn_canceled`** → muted row: "Canceled: <reason>".
- **Auto-retry (pi `auto_retry_*` → daemon turn events)** → single in-place status line on the pending assistant row: "Retrying (attempt 2/5, error: …)". Replace in place; never spawn extra rows per attempt.
- **`turn_completed`** → no row. Usage updates flow only into the composer pill.

## 5. Composer

- Usage pill already reads `usage_updated` / `turn_completed` (`AgentUsage`), cost + cached/input/output tokens. Keep host-scoped settings.

---

## 6. Out of design scope (provider drops them)

`branchSummary` (branch switches invisible), `queue_update` (no steering/queued-question UI), `session_info_changed`, `entry_appended`, toolcall args streaming, `toolResult.details`. Revisit only if Paseo's provider starts forwarding them; do not build speculative UI.

If extension custom entries or per-tool metadata are ever needed in the timeline: `plugin` timeline items via timeline-ui's own server RPC (pattern already proven by `split-probe`), not prose parsing.

---

## 7. Open decision gate: split answer fragments

Resolved by runtime evidence (17-09-2026): the host re-runs transforms on completed items at scale — 3208 re-runs across 92 distinct completed assistant items in one session (`/var/folders/.../T/paseo-timeline-probe.log`, pre-restart sampling). Item objects are re-created, so gated merging of split fragments is technically enabled. However, continuation styling (commit a9765dd) already renders split answers acceptably. Decision: keep continuation styling as the default; revisit gated merging only if a real split-answer case renders badly in the client. The split-probe instrumentation can be removed at that point or when merging lands.

---

## 8. Implementation order

1. §4 rows (failed/canceled/retry): `shared/transform-turn-status.ts` + `client/turn-status.tsx`, ~120 LoC, no settings.
2. §3.6 error/notification rows: reuse turn-status anatomy, ~80 LoC.
3. §3.6 todo card: `client/todo-card.tsx`, ~100 LoC.
4. §3.2 transient reasoning cap: `shared/reasoning.ts` + `client/reasoning.tsx`, ~40 LoC, bump `REASONING_RENDERER_VERSION` to 3.
5. §7 decision gate, then either merge logic (~60 LoC) or probe removal (~30 LoC deletion).

Versioning rule per README: any schema change bumps both the transformer output version and the matching `addTimelineRenderer` version. Sync source of truth to `~/dotfiles/sources/paseo/plugins/timeline-ui/` after each step.

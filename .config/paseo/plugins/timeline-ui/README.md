# timeline-ui

Paseo plugin that renders Pi-style attention blocks and shows live session usage in the composer. Formerly `attention-blocks-timeline`.

When an assistant message contains paragraphs like:

```markdown
**→ Lead-in.** Rest of the paragraph.
```

the built-in assistant row is replaced with tinted status-style cards inside **one timeline row** (no explode-into-rows duplication during streaming).

## Theme vs card colors

| Layer | Where | What you get |
| --- | --- | --- |
| **App chrome** | Settings → Appearance → **Zinc** (built-in) | Exact Zinc look — sidebar, chat background, buttons |
| **Card stripes** | `shared/block-variants.ts` | Six plugin-owned hex colors; resolved at render from block index |
| **Card icons** | `shared/block-icon.ts` | Keyword/heuristic Lucide pick from title + body; omitted when no match |

Do **not** use a contributed dark theme for Zinc parity. `addTheme` only accepts 8 hex keys; Paseo derives the rest. Built-in Zinc sets every surface token explicitly, so a plugin theme will always drift (wrong raised/control ladder, sidebar, shadows).

Optional: **Dotfiles Cards (Light)** for light mode only (`client/themes.ts`).

## Settings

Open **Settings → Plugins → timeline-ui**.

| Section | Setting | Options |
| --- | --- | --- |
| Timeline messages | Attention cards | On / off |
| Timeline messages | Stable streaming | On / off |
| Timeline messages | Prose density | Compact, default, comfortable |
| Attention cards | Content icons, border, background tint | Multiple display options |
| Reasoning | Expansion mode | Collapsed, latest expanded, expanded |
| Composer | Session usage | On / off |
| Composer | Usage label | Cost, cost and tokens |

The session-usage pill opens a compact breakdown of cost, input, cached, and output tokens. Settings are host-scoped, so all clients on the daemon share them.

## Customize

| File | What to change |
| --- | --- |
| `client/card-settings.tsx` | Card settings labels and options |
| `client/composer-settings.tsx` | Session-usage pill settings |
| `client/session-usage-pill.tsx` | Live cost/token pill registration and details |
| `shared/preferences.ts` | Defaults and opacity/border enums |
| `shared/composer-preferences.ts` | Composer visibility and label defaults |
| `shared/card-display.ts` | Border layout + tint math |
| `client/attention-block.tsx` | Card render wiring |
| `shared/block-variants.ts` | Hex accent colors per variant |
| `shared/block-icon.ts` | Keyword → icon rules |

Bump `version` in transformer output and `addTimelineRenderer` when changing the schema.

## Install

```bash
paseo plugin install ~/dotfiles/.config/paseo/plugins/timeline-ui
paseo plugin reload timeline-ui
```

Dark mode: select **Zinc** in Settings → Appearance. Card colors apply automatically.

## Test

```bash
cd ~/dotfiles/.config/paseo/plugins/timeline-ui
npm install
npm test
npm run typecheck
```

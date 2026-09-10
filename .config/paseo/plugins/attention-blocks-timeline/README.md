# attention-blocks-timeline

Paseo client plugin that renders PI-style attention blocks in the agent timeline.

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

**Settings → Plugins → attention-blocks-timeline → Attention cards**

| Setting | Options |
| --- | --- |
| Content icons | On / off |
| Border | None, box, left accent, top accent |
| Background tint | 0%–22% opacity presets (accent color wash) |

Host-scoped — all clients on this daemon share values. Requires `index.server.ts` (settings persistence).

## Customize

| File | What to change |
| --- | --- |
| `client/card-settings.tsx` | Settings screen labels and options |
| `shared/preferences.ts` | Defaults and opacity/border enums |
| `shared/card-display.ts` | Border layout + tint math |
| `client/attention-block.tsx` | Card render wiring |
| `shared/block-variants.ts` | Hex accent colors per variant |
| `shared/block-icon.ts` | Keyword → icon rules |

Bump `version` in transformer output and `addTimelineRenderer` when changing the schema.

## Install

```bash
paseo plugin install ~/dotfiles/.config/paseo/plugins/attention-blocks-timeline
paseo plugin reload attention-blocks-timeline
```

Dark mode: select **Zinc** in Settings → Appearance. Card colors apply automatically.

## Test

```bash
cd ~/dotfiles/.config/paseo/plugins/attention-blocks-timeline
npm install
npm test
npm run typecheck
```

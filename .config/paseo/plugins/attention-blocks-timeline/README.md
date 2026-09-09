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
| **Card stripes/icons** | `shared/block-variants.ts` | Plugin-owned hex palette (blue, violet, amber, coral) — independent of theme |

Do **not** use a contributed dark theme for Zinc parity. `addTheme` only accepts 8 hex keys; Paseo derives the rest. Built-in Zinc sets every surface token explicitly, so a plugin theme will always drift (wrong raised/control ladder, sidebar, shadows).

Optional: **Dotfiles Cards (Light)** for light mode only (`client/themes.ts`).

## Customize

| File | What to change |
| --- | --- |
| `client/attention-block.tsx` | Single-card layout and typography |
| `client/attention-message.tsx` | Stack layout (intro / cards / outro) |
| `shared/block-variants.ts` | Icon + **hex stripe/icon colors** per variant |
| `shared/attention-blocks.ts` | Parser regex / paragraph rules |
| `shared/attention-message.ts` | Transformer logic |

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

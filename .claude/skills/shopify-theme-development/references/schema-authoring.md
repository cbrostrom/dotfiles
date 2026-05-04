---
name: schema-authoring
description: TypeScript schema system for Shopify theme sections, blocks, and settings.
---

# Schema Authoring

The project uses TypeScript to author Shopify section schemas. The build system compiles these to JSON and injects them into `.liquid` files between `{% schema %}` and `{% endschema %}` tags.

## Architecture

```
stores/{store}/src/schemas/
  sections/          # Section schemas → injected into theme/sections/*.liquid
  settings/          # Reusable setting factory functions
  configs/           # Theme config schemas → theme/config/settings_schema.json
  blocks/            # Block factory functions
  section-blocks/    # Section block schemas (translation extraction only)
  section-groups/    # Section group schemas
  types/
    schemaTypes.d.ts # TypeScript type definitions
```

## Core Types

### SchemaSection

The main type for section schemas:

```typescript
type SchemaSection = {
  name: string;
  tag?: string;
  class?: string;
  disabled_on?: {
    groups?: string[];
    templates?: string[];
  };
  enabled_on?: {
    groups?: string[];
    templates?: string[];
  };
  settings?: SchemaSetting[];
  blocks?: SchemaSectionBlock[];
  presets?: SchemaBasePreset[];
};
```

### SchemaSetting

Settings are a union type covering all Shopify setting types:

| Type | Factory | Description |
|------|---------|-------------|
| `text` | `TextSetting()` | Single-line text input |
| `textarea` | `TextareaSetting()` | Multi-line text |
| `richtext` | `RichtextSetting()` | Rich text editor |
| `number` | `NumberSetting()` | Numeric input |
| `range` | `RangeSetting()` | Range slider |
| `checkbox` | `CheckboxSetting()` | Boolean toggle |
| `select` | `SelectSetting()` | Dropdown select |
| `radio` | `RadioSetting()` | Radio buttons |
| `color` | `ColorSetting()` | Color picker |
| `color_scheme` | `ColorSchemeSetting()` | Color scheme selector |
| `image_picker` | `ImagePickerSetting()` | Image upload |
| `video` | `VideoSetting()` | Video selector |
| `video_url` | `VideoUrlSetting()` | Video URL input |
| `url` | `UrlSetting()` | URL input |
| `product` | `ProductSetting()` | Product picker |
| `collection` | `CollectionSetting()` | Collection picker |
| `page` | `PageSetting()` | Page picker |
| `blog` | `BlogSetting()` | Blog picker |
| `article` | `ArticleSetting()` | Article picker |
| `header` | `HeaderSetting()` | Section header (visual divider in editor) |
| `paragraph` | `ParagraphSetting()` | Info paragraph in editor |
| `liquid` | `LiquidSetting()` | Custom Liquid input |

## Writing Section Schemas

### Basic section

```typescript
import type { SchemaSection } from '@/schemas/types/schemaTypes';
import { HeaderSetting, TextSetting, RichtextSetting, ImagePickerSetting } from '@/schemas/settings';
import { PaddingTopSetting, PaddingBottomSetting, ThemeSetting } from '@/schemas/settings';

const sectionName = 'Featured Content';

export default {
  name: sectionName,
  tag: 'section',
  enabled_on: {
    templates: ['index', 'page'],
  },
  settings: [
    HeaderSetting({ content: 'Content' }),
    TextSetting({ id: 'heading', label: 'Heading' }),
    RichtextSetting({ id: 'body', label: 'Body text' }),
    ImagePickerSetting({ id: 'image', label: 'Image' }),

    HeaderSetting({ content: 'Section padding' }),
    PaddingTopSetting(),
    PaddingBottomSetting(),
    ThemeSetting(),
  ],
  presets: [
    {
      name: sectionName,
    },
  ],
} as SchemaSection;
```

### Section with blocks

```typescript
import type { SchemaSection } from '@/schemas/types/schemaTypes';
import { HeaderSetting, RangeSetting } from '@/schemas/settings';
import { HeadingBlock, RichTextRowBlock, ButtonBlock, ImageBlock } from '@/schemas/blocks';

const sectionName = 'Multirow';

export default {
  name: sectionName,
  tag: 'section',
  enabled_on: {
    templates: ['index', 'page', 'product', 'collection'],
    groups: ['footer'],
  },
  settings: [
    HeaderSetting({ content: 'Layout' }),
    RangeSetting({
      id: 'columns',
      label: 'Columns',
      min: 1,
      max: 4,
      step: 1,
      defaultValue: 2,
    }),
  ],
  blocks: [
    HeadingBlock(),
    RichTextRowBlock(),
    ButtonBlock(),
    ImageBlock(),
  ],
  presets: [
    {
      name: sectionName,
      blocks: [
        { type: 'heading' },
        { type: 'rich_text_row' },
      ],
    },
  ],
} as SchemaSection;
```

## Writing Setting Factories

Setting factories are functions that return a setting object. They use `snakifyString` to convert human-readable IDs to snake_case:

```typescript
import type { RangeSchemaType } from '@/schemas/types/schemaTypes';
import { snakifyString } from '@shared/scripts/utils/snakifyString';

export const RangeSetting = ({
  id = 'range',
  label = 'Range',
  min = 0,
  max = 100,
  step = 1,
  unit = 'px',
  defaultValue = 50,
  info = '',
  visibleIf = '',
} = {}): RangeSchemaType => ({
  type: 'range',
  id: snakifyString(id),
  label,
  defaultLabel: label,
  min,
  max,
  step,
  unit,
  default: defaultValue,
  ...(info && { info }),
  ...(visibleIf && { visible_if: visibleIf }),
});

export default RangeSetting;
```

### Convention: `defaultLabel`

Setting factories include a `defaultLabel` property that stores the original English label. The build system uses this to generate translation keys and then strips it from the final output.

## Writing Block Factories

Block factories follow the same pattern as setting factories:

```typescript
import type { SchemaSectionBlock } from '@/schemas/types/schemaTypes';
import { TextSetting, SelectSetting } from '@/schemas/settings';

export const HeadingBlock = (): SchemaSectionBlock => ({
  type: 'heading',
  name: 'Heading',
  settings: [
    TextSetting({ id: 'heading', label: 'Heading text' }),
    SelectSetting({
      id: 'heading_size',
      label: 'Heading size',
      defaultValue: 'h2',
      options: [
        { label: 'Small', value: 'h3' },
        { label: 'Medium', value: 'h2' },
        { label: 'Large', value: 'h1' },
      ],
    }),
  ],
});
```

## Writing Config Schemas

Config schemas define the theme-level settings in `settings_schema.json`. They use named exports:

```typescript
import { HeaderSetting, CheckboxSetting, ColorSetting } from '@/schemas/settings';

const configName = 'Typography';

export const TypographyConfig = () => ({
  name: configName,
  settings: [
    HeaderSetting({ content: 'Headings' }),
    ColorSetting({ id: 'heading_color', label: 'Heading color', defaultValue: '#000000' }),

    HeaderSetting({ content: 'Body' }),
    ColorSetting({ id: 'body_color', label: 'Body color', defaultValue: '#333333' }),
  ],
});
```

The naming convention is `{PascalCaseName}Config` where the name matches the filename. The build system imports these by convention.

## Build Pipeline Details

### How TS becomes Liquid schema

1. Build system dynamic-imports the schema's default export
2. If the export is a function, it calls it to get the schema object
3. `removeLabels()` strips build-only keys (`originalLabel`, `defaultLabel`, `fieldType`)
4. `addTranslationKeys()` replaces human-readable strings with `t:sections.{name}.settings.{id}.label` keys
5. Schema JSON is formatted and written between `{% schema %}` / `{% endschema %}` in the matching `.liquid` file

### How configs become settings_schema.json

1. Build system imports all `{Name}Config` named exports from `src/schemas/configs/`
2. `theme-info` config is handled specially (always first entry)
3. All configs are aggregated into a JSON array
4. Written to `theme/config/settings_schema.json`

### Translation key format

```
Section settings: t:sections.{section-name}.settings.{setting-id}.label
Block settings:   t:sections.{section-name}.blocks.{block-type}.settings.{setting-id}.label
Config settings:  t:settings_schema.{config-name}.settings.{setting-id}.label
```

## Important Rules

- **Always run `npm run build:prepare`** after editing schema files
- **Never edit the generated `{% schema %}` JSON** in `.liquid` files directly
- **Never edit `settings_schema.json`** directly -- edit the TypeScript config schemas
- **Use `snakifyString`** for all setting IDs to ensure consistent snake_case
- **Include `defaultLabel`** in setting factories so the build can generate translations
- **Match filenames to section names** -- the build maps `product-grid.ts` to `sections/product-grid.liquid`

# Vivaldi common.css Reference Map

> Auto-generated reference for `common.css` (35,511 lines)
> Use this instead of searching the full file

---

## Core CSS Variables

### Colors (Set by Vivaldi theme engine)

| Variable | Description |
|----------|-------------|
| `--colorFg` | Primary foreground/text color |
| `--colorFgFaded` | Faded foreground |
| `--colorFgFadedMore` | More faded foreground |
| `--colorFgFadedMost` | Most faded foreground |
| `--colorFgIntense` | Intense foreground |
| `--colorFgAlpha` | Semi-transparent foreground |
| `--colorBg` | Primary background |
| `--colorBgLight` | Light background |
| `--colorBgLighter` | Lighter background |
| `--colorBgDark` | Dark background |
| `--colorBgDarker` | Darker background |
| `--colorBgIntense` | Intense background |
| `--colorBgIntenser` | More intense background |
| `--colorBgInverse` | Inverse background |
| `--colorBgAlpha` | Semi-transparent background |
| `--colorBgFaded` | Faded background |

### Accent Colors

| Variable | Description |
|----------|-------------|
| `--colorAccentBg` | Accent background (active tabs, etc.) |
| `--colorAccentBgDark` | Dark accent background |
| `--colorAccentBgDarker` | Darker accent background |
| `--colorAccentBgAlpha` | Semi-transparent accent |
| `--colorAccentBgAlphaHeavy` | Heavy alpha accent |
| `--colorAccentBgFaded` | Faded accent |
| `--colorAccentBgFadedMore` | More faded accent |
| `--colorAccentFg` | Accent foreground |
| `--colorAccentFgFaded` | Faded accent foreground |
| `--colorAccentFgAlpha` | Alpha accent foreground |
| `--colorAccentBorder` | Accent border color |

### Highlight Colors

| Variable | Description |
|----------|-------------|
| `--colorHighlightBg` | Highlight background (focus rings) |
| `--colorHighlightFg` | Highlight foreground |
| `--colorHighlightFgAlpha` | Alpha highlight foreground |

### Image/Transparent Tabbar Colors

| Variable | Description |
|----------|-------------|
| `--colorImageFg` | Foreground over background image |
| `--colorImageBg` | Background over image |
| `--colorImageBgAlpha` | Alpha background over image |
| `--colorImageBgAlphaHeavy` | Heavy alpha over image |
| `--colorImageTopFg` | Top area image foreground |
| `--colorImageLeftFg` | Left sidebar image foreground |
| `--colorImageRightFg` | Right sidebar image foreground |

### Layout & Sizing

| Variable | Default | Description |
|----------|---------|-------------|
| `--densityGap` | `3px` | Base gap unit for density mode |
| `--radius` | `7px` | Standard border radius |
| `--radiusHalf` | `4px` | Half radius |
| `--radiusWindow` | Window corner radius |
| `--radiusCap` | Capped radius |
| `--radiusRounded` | Fully rounded |
| `--uiZoomLevel` | `1` | UI zoom multiplier |
| `--scrollbarWidth` | System scrollbar width |

### Toolbar Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `--ToolbarItemGap` | `0` or `6px` | Gap between toolbar items |
| `--Height` | Tab height |
| `--Width` | Tab width |

### Tab Bar Colors

| Variable | Description |
|----------|-------------|
| `--colorTabBar` | Tab bar background |
| `--verticalTabSpace` | `6px` or `3px` | Vertical tab spacing |

---

## Sidebar Structure (tabs-left / tabs-right)

### Container Hierarchy

```
#browser.tabs-left / #browser.tabs-right
└── .tabbar-wrapper
    └── #tabs-container.left / #tabs-container.right
        ├── .toolbar-mainbar[aria-label]  (address bar, extensions, buttons)
        │   ├── .UrlBar-AddressField
        │   ├── .toolbar-extensions
        │   ├── .button-toolbar
        │   └── [name="WorkspaceButton"]
        ├── .tab-strip
        │   ├── .tab-position
        │   │   └── .tab-wrapper
        │   │       └── .tab
        │   │           └── .tab-header
        │   └── .newtab
        └── .toolbar-panel (bottom buttons)
```

### Key Sidebar Selectors

#### Tabbar Wrapper
```css
/* Line 3411-3417 */
.tabs-left .tabbar-wrapper,
.tabs-right .tabbar-wrapper {
  position: relative;
  display: flex;
  flex-direction: column;
  height: 100%;
}
```

#### Tab Strip (Sidebar Mode)
```css
/* Line 11261-11268 */
#tabs-container.left .tab-strip,
#tabs-container.right .tab-strip {
  margin: 0 max(calc(var(--densityGap) * 2), 1px);  /* 6px side margin */
  max-width: calc(100% - var(--densityGap) * 2);
  padding: 0;
  overflow-x: hidden;
  overflow-y: auto;
}
```

#### Tab Strip Overflow
```css
/* Line 11274-11277 */
#tabs-container.left .tab-strip.overflow,
#tabs-container.right .tab-strip.overflow {
  margin: 0 0 0 max(calc(var(--densityGap) * 2), 1px);
  min-width: calc(30px + var(--scrollbarWidth));
}
```

#### Tab Header
```css
/* Line 10506-10512 */
.tab .tab-header {
  display: flex;
  flex: 0 0 30px;  /* DEFAULT HEIGHT - Override with flex: 0 0 Xpx */
  position: relative;
  max-width: 100%;
  overflow: hidden;
  align-items: center;
}
```

#### Active Tab
```css
/* Line 10389-10391 */
#browser .tab.active {
  background-color: var(--colorAccentBg);
  color: var(--colorAccentFg);
}

/* Color behind tabs ON */
#browser.color-behind-tabs-on .tab.active.active {
  background-color: var(--colorBg);
  color: var(--colorFg);
}
```

#### Pinned Tabs
```css
/* Line 10481-10487 */
.tab.pinned .close,
.tab.pinned:hover .close {
  display: none !important;
}
.tab.pinned .favicon,
.tab.pinned:hover .favicon {
  visibility: visible !important;
}
```

---

## Workspace Button

```css
/* Line 7187-7220 */
.button-toolbar.workspace-popup {
  text-overflow: ellipsis;
  max-width: 160px;
  color: inherit;
}

#app div:not(.draggable-button) > .button-toolbar.workspace-popup button {
  gap: 3px;
  padding: 0 3px;
  border: 0;
}

.tabbar-wrapper .button-toolbar.workspace-popup.tabbar-workspace-button button {
  z-index: 1;
  height: inherit;
  border-radius: var(--radiusHalf);
}

.density-on .tabbar-wrapper .button-toolbar.workspace-popup.tabbar-workspace-button button {
  border-radius: var(--radius);  /* 7px in density mode */
}

/* Sidebar-specific */
.tabs-left #tabs-tabbar-container .button-toolbar.workspace-popup,
.tabs-right #tabs-tabbar-container .button-toolbar.workspace-popup {
  max-width: unset;
  width: stretch;
}
```

---

## New Tab Button

```css
/* Line 3487-3488 */
.toolbar-tabbar .newtab > button svg {
  border-radius: var(--radius);
}
```

---

## Button Toolbar

```css
/* Line 2010-2013 */
.toolbar > .button-toolbar,
.toolbar > .toolbar-wrap > .button-toolbar,
.toolbar > .toolbar-group > .button-toolbar,
.toolbar > input {
  flex: 0 1 auto;
}

/* Active state */
.toolbar > .button-toolbar.button-on,
.toolbar > .toolbar-group .button-toolbar.button-on {
  fill: var(--colorHighlightBg);
  color: var(--colorHighlightBg);
}
```

---

## URL Bar

```css
/* Sidebar rotation (vertical mode) - Line 2804-2809 */
#panels-container.left #switch > .toolbar.toolbar-vertical .UrlBar-AddressField {
  transform: rotate(270deg) translateX(-136px);
  width: 300px;
  margin: 0 0 272px;
  padding: 0 6px;
  flex: 0 0 auto;
}
```

---

## Density Mode Classes

| Class | Description |
|-------|-------------|
| `.density-on` | Density mode enabled (adds gaps) |
| `.tabs-at-edge` | Tabs at window edge |
| `.color-behind-tabs-on` | Accent color behind tabs |
| `.color-behind-tabs-off` | No accent behind tabs |
| `.transparent-tabbar` | Transparent tab bar |

### Density Calculations

```css
/* Header heights include density gap */
min-height: calc((36px + var(--densityGap) * 2) / var(--uiZoomLevel));

/* Tab strip margin in sidebar */
margin: 0 max(calc(var(--densityGap) * 2), 1px);  /* 6px */
```

---

## Browser State Classes

Applied to `#browser`:

| Class | Description |
|-------|-------------|
| `.tabs-left` | Tabs on left side |
| `.tabs-right` | Tabs on right side |
| `.tabs-top` | Tabs on top |
| `.tabs-bottom` | Tabs on bottom |
| `.mac` / `.win` / `.linux` | Operating system |
| `.fullscreen` | Fullscreen mode |
| `.isblurred` | Window not focused |
| `.dim-blurred` | Dim when blurred |
| `.theme-dark` | Dark theme |
| `.acc-dark` | Dark accent |
| `.bg-dark` | Dark background |

---

## Common Patterns

### Side Margin Pattern (6px)
```css
margin: 0 max(calc(var(--densityGap) * 2), 1px);
/* Ensures minimum 1px, typically 6px */
```

### Border Radius Pattern
```css
border-radius: var(--radius);        /* 7px - standard */
border-radius: var(--radiusHalf);    /* 4px - smaller */
border-radius: var(--radiusRounded); /* fully rounded */
```

### Alpha/Hover Pattern
```css
background-color: var(--colorAccentBgAlpha);       /* light hover */
background-color: var(--colorAccentBgAlphaHeavy);  /* heavy hover */
```

---

## Z-Index Hierarchy

| Element | Z-Index |
|---------|---------|
| `.tab-strip:focus-within` | 6 |
| URL bar focus | 2 |
| Dropzone | 6 |
| Toolbar on focus | 6 |

---

## Important Line References

| Element | Lines |
|---------|-------|
| Root variables | 1-5 |
| Tabbar wrapper | 3411-3420 |
| Tab strip (sidebar) | 11261-11277 |
| Tab header | 10506-10516 |
| Active tab | 10389-10410 |
| Workspace button | 7187-7226 |
| Density calculations | 525-536 |

---

## Full Variable Quick Reference

### Primary Colors (from theme engine)
```css
--colorFg              /* Text color */
--colorFgFaded         /* Faded text */
--colorFgFadedMore     /* More faded */
--colorFgFadedMost     /* Most faded */
--colorFgIntense       /* Intense text */
--colorFgAlpha         /* Alpha text */
--colorBg              /* Background */
--colorBgLight         /* Light bg */
--colorBgLighter       /* Lighter bg */
--colorBgDark          /* Dark bg */
--colorBgDarker        /* Darker bg */
--colorBgIntense       /* Intense bg */
--colorBgIntenser      /* More intense bg */
--colorBgInverse       /* Inverse bg */
--colorBgInverser      /* More inverse bg */
--colorBgFaded         /* Faded bg */
--colorBgAlpha         /* Alpha bg */
--colorBorder          /* Border */
--colorBorderIntense   /* Intense border */
```

### Accent Colors
```css
--colorAccentBg           /* Accent background */
--colorAccentBgDark       /* Dark accent */
--colorAccentBgDarker     /* Darker accent */
--colorAccentBgAlpha      /* Alpha accent */
--colorAccentBgAlphaHeavy /* Heavy alpha */
--colorAccentBgFaded      /* Faded accent */
--colorAccentBgFadedMore  /* More faded */
--colorAccentBgFadedMost  /* Most faded */
--colorAccentBorder       /* Accent border */
--colorAccentBorderDark   /* Dark accent border */
--colorAccentFg           /* Accent foreground */
--colorAccentFgFaded      /* Faded accent fg */
--colorAccentFgAlpha      /* Alpha accent fg */
```

### Highlight Colors
```css
--colorHighlightBg        /* Highlight bg (focus) */
--colorHighlightBgAlpha   /* Alpha highlight */
--colorHighlightFg        /* Highlight fg */
--colorHighlightFgAlpha   /* Alpha highlight fg */
```

### Layout Variables (from settings)
```css
--densityGap     /* 3px - base spacing unit */
--radius         /* 7px - border radius */
--radiusHalf     /* 4px - half radius */
--radiusWindow   /* Window corner radius */
--radiusCap      /* Capped radius */
--radiusRounded  /* Fully rounded */
--uiZoomLevel    /* UI zoom multiplier */
```

### Computed Spacing
```css
calc(var(--densityGap) * 2)  /* 6px - standard sidebar margin */
calc(var(--densityGap) * 3)  /* 9px */
calc(var(--densityGap) * 4)  /* 12px */
```

---

## Usage Notes

1. **Override specificity**: Vivaldi uses long selector chains. Match or exceed specificity.

2. **Density mode**: Always test with `.density-on` class as it changes spacing.

3. **Color behind tabs**: Styles differ between `.color-behind-tabs-on` and `.color-behind-tabs-off`.

4. **Use Vivaldi variables**: Prefer `var(--densityGap)`, `var(--radius)` over hardcoded values.

5. **Sidebar-specific**: Many styles are scoped to `.tabs-left` or `.tabs-right`.

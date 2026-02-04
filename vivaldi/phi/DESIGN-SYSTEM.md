# Phi Theme - Design System

## Spacing Scale (8px Base)

All spacing follows an 8px base scale for visual consistency:

| Variable | Value | Usage |
|----------|-------|-------|
| `--phi--spacing-micro` | 2px | Borders, tiny gaps, column-gap |
| `--phi--spacing-tiny` | 4px | Tight element spacing, small padding |
| `--phi--spacing-small` | 8px | Standard gap, base padding unit |
| `--phi--spacing-medium` | 12px | Comfortable spacing, text padding |
| `--phi--spacing-large` | 16px | Section separation |
| `--phi--spacing-xl` | 24px | Major section breaks |

## Tab System

### Dimensions
```css
--phi--tab-height: 48px           /* 6 × 8px base */
--phi--tab-spacing: 8px            /* Gap between tabs */
--phi--tab-padding-x: 12px         /* Horizontal padding inside tab */
--phi--tab-padding-y: 8px          /* Vertical padding inside tab */
--phi--tab-border-radius: 8px      /* Rounded corners */
```

### Structure
- Total tab height: 48px (content + padding with box-sizing: border-box)
- Gap between tabs: 8px
- Border: 1px solid transparent (49px total with border)
- Content area: 48px - (8px × 2) = 32px for icon + text

### States
- **Normal**: `background-color: var(--colorAccentBgAlphaHeavy)`
- **Hover**: Scale 1.02, border color change, 2px translateX
- **Active**: Border color, box-shadow: 0 2px 8px

## Pinned Tabs

### Dimensions
```css
--phi--pinned-tab-max-height: 64px      /* 8 × 8px base */
--phi--pinned-tab-aspect-ratio: 1.2     /* Width:height ratio */
--phi--pinned-tab-border-radius: 8px    /* Rounded corners */
```

### Calculated
- Width: 64px × 1.2 = ~77px (depends on aspect ratio)
- Favicon: 20px (8px × 2.5)
- Padding: 8px all sides

## Sidebar

### Dimensions
```css
--phi--sidebar-width: 344px            /* ~43 × 8px */
--phi--sidebar-padding: 8px            /* Internal padding */
--phi--compact-sidebar-width: 50px     /* Compact mode */
```

### Layout
- Grid columns: 4 for pinned tabs
- Padding: 8px left/right
- Total usable width: 344px - 16px = 328px

## Buttons

### Dimensions
```css
--phi--button-size: 32px               /* 4 × 8px base */
--phi--button-border-radius: 8px       /* Rounded corners */
--phi--button-margin: 8px              /* Spacing around buttons */
```

### Types
- **Extension buttons**: 32×32px, margin 2px, hover scale 1.05
- **Workspace button**: Full width, margin 8px, hover lift -2px
- **Panel buttons**: Standard size, no margin override

## Transitions & Animations

### Timing
```css
--phi--transition-speed: 0.2s          /* Standard duration */
```

### Hover Effects
```css
--phi--hover-scale-small: 1.02         /* Subtle scale (tabs, small elements) */
--phi--hover-scale-medium: 1.05        /* Medium scale (buttons, icons) */
--phi--hover-lift: -2px                /* Vertical lift on hover */
```

### Applied To
- All interactive elements use `transition: all var(--phi--transition-speed) ease`
- Hardware acceleration via `will-change: transform` and `backface-visibility: hidden`

## Border Radius System

Consistent rounded corners:
- **Tabs**: 8px
- **Buttons**: 8px
- **Pinned tabs**: 8px
- **Webview**: 8px (configurable)
- **Tab groups**: 8px left, 0px right (connects to indicators)

## Shadows

### Levels
- **Subtle**: `0 2px 6px rgba(0, 0, 0, 0.1)` - Hover states
- **Medium**: `0 2px 8px rgba(0, 0, 0, 0.1)` - Active tabs
- **Strong**: `0 4px 12px rgba(0, 0, 0, 0.15)` - Pinned tab hover
- **Webview**: `0 0 12px rgba(0, 0, 0, 0.15)` - Page container

## Typography

### Font Sizes
- Tab title: 13px
- Tab indicator text: 13px
- Extension empty state: 0.75rem (~12px)

### Font Smoothing
```css
-webkit-font-smoothing: antialiased;
-moz-osx-font-smoothing: grayscale;
```

## Color System (Inherited from Vivaldi Theme)

Uses Vivaldi's built-in color variables:
- `--colorFg` - Foreground text
- `--colorBg` - Background
- `--colorAccentBg` - Accent background
- `--colorAccentFg` - Accent foreground
- `--colorAccentBgAlpha` - Semi-transparent accent
- `--colorAccentBgAlphaHeavy` - More transparent accent
- `--colorHighlightBg` - Highlight color

## Grid System

### Main Layout
```css
display: grid;
grid-template-rows: auto auto 1fr auto;
grid-template-columns: [sidebar] [content];
```

### Toolbar Grid
```css
grid-template-rows: 1fr 1fr auto;
grid-template-columns: repeat(var(--phi--toolbar-column-count), calc(100% / count));
```

### Tab Strip Grid
```css
grid-template-columns: repeat(var(--phi--pinned-column-count), minmax(0, 1fr));
grid-auto-rows: min-content;
gap: var(--phi--tab-spacing);
```

## Responsive Behavior

### Compact Mode
Triggered by:
- `--phi--is-auto-compact-mode: 1` + no hover
- Manual compact toggle

Changes:
- Sidebar: 344px → 50px
- Tab titles hidden, only favicons shown
- Toolbar hidden (except Mac with window controls)
- Workspace button title hidden

### Panel States
- **Closed**: Panel buttons in horizontal row at bottom
- **Open**: Panel overlay with backdrop-filter blur

## Accessibility

- All interactive elements have visible focus states
- Minimum touch target: 32×32px (buttons)
- Tab height: 48px (comfortable for clicking)
- Keyboard navigation supported
- ARIA labels preserved

## Performance Optimizations

### Hardware Acceleration
Applied to animated elements:
```css
will-change: transform;
backface-visibility: hidden;
-webkit-backface-visibility: hidden;
```

### Smooth Scrolling
```css
scroll-behavior: smooth; /* On .tab-strip */
```

## Customization Quick Reference

Want taller tabs? → Increase `--phi--tab-height` (multiples of 8: 40, 48, 56, 64)
Want more spacing? → Increase `--phi--tab-spacing` (4, 8, 12, 16)
Want bigger buttons? → Increase `--phi--button-size` (24, 32, 40)
Want slower animations? → Increase `--phi--transition-speed` (0.2s, 0.3s, 0.4s)
Want smaller pinned tabs? → Decrease `--phi--pinned-tab-max-height` (48, 56, 64)

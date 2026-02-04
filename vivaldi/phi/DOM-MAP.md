# Vivaldi Phi Theme - DOM Structure Map

## Complete Tab Structure

```
#app
└── #browser.mac.tabs-left
    ├── #main.left
    │   └── .mainbar
    │       └── .toolbar.toolbar-mainbar.toolbar-addressbar
    │           ├── .window-buttongroup
    │           ├── .button-toolbar (Panel Toggle)
    │           ├── .button-toolbar (Back button)
    │           ├── .button-toolbar (Forward button)
    │           ├── .button-toolbar (Reload button)
    │           ├── .UrlBar-AddressField
    │           │   ├── .toolbar.toolbar-insideinput (left icons)
    │           │   ├── .UrlBar-UrlFieldWrapper
    │           │   │   └── .UrlField
    │           │   │       └── input#urlFieldInput.UrlBar-UrlField
    │           │   └── .toolbar.toolbar-insideinput (right icons)
    │           │       └── .BookmarkButton
    │           └── .toolbar-extensions
    │               ├── .button-toolbar.ExtensionIcon (uBlock Origin)
    │               ├── .button-toolbar.ExtensionIcon (Bitwarden)
    │               └── .button-toolbar (Show hidden extensions)
    │
    ├── .tabbar-wrapper
    │   └── #tabs-tabbar-container.left
    │       └── #tabs-container[role="toolbar"]
    │           ├── .toolbar.toolbar-tabbar-before
    │           │   └── .button-toolbar.workspace-popup
    │           │       └── button[name="WorkspaceButton"]
    │           │           ├── span.button-icon
    │           │           ├── span.button-title
    │           │           └── span.button-toolbar-menu-indicator
    │           │
    │           ├── .resize
    │           │   └── .tab-strip[role="tablist"]
    │           │       └── span (wrapper for each tab)
    │           │           └── .tab-position
    │           │               [inline style: --PositionX, --PositionY, --Height, --Width, --ZIndex]
    │           │               └── .tab-wrapper[role="tab"]
    │           │                   [classes: .extended, .active (if active)]
    │           │                   └── .tab
    │           │                       [classes: .force-hover, .active (if active), 
    │           │                        .isdiscarded (if hibernated), .periodic-reload]
    │           │                       └── .tab-header
    │           │                           ├── progress.page-progress-indicator
    │           │                           ├── span.favicon
    │           │                           │   └── img[width="16" height="16"]
    │           │                           ├── span.title (tab title text)
    │           │                           └── button.close
    │           │                               └── svg (close icon)
    │           │
    │           └── .toolbar.toolbar-tabbar-after
    │               ├── .button-toolbar.newtab
    │               │   └── button[name="NewTab"]
    │               ├── .button-toolbar.toolbar-spacer-flexible
    │               └── .button-toolbar.tabs-button
    │                   └── button[name="TabButton"]
    │
    ├── #panels-container.left
    │   └── #panels
    │       └── #switch
    │           └── .toolbar.toolbar-panel
    │               ├── .button-toolbar (Bookmarks panel)
    │               ├── .button-toolbar (Downloads panel)
    │               ├── .button-toolbar (History panel)
    │               ├── .button-toolbar (Notes panel)
    │               ├── .button-toolbar (Translate panel)
    │               ├── .button-toolbar.toolbar-divider
    │               ├── .button-toolbar.button-toolbar-webpanel (Web panels...)
    │               └── .button-toolbar (Add Web Panel)
    │
    └── #webview-container
        └── #webpage-stack
            └── .webpageview.active
                └── .row-wrapper
                    └── .devtools-container
                        └── .webpage
                            └── webview[role="document"]
```

## Key Inline Styles (Set by Vivaldi dynamically)

### .tab-position
```html
style="--PositionX: 0px; --PositionY: 0px; --Height: 33px; --Width: 312px; --ZIndex: 1;"
```

### #tabs-container
```html
style="--spacerRows: 1;"
```

### #tabs-tabbar-container
```html
style="width: 283px; height: stretch;"
```

## Current CSS Selectors We Use

### Tab Height Control
- `.tab-position:not(.is-pinned)` - Container with inline `--Height: 33px`
- `.tab-position:not(.is-pinned) .group` - Visual border wrapper
- `.tab-position:not(.is-pinned) .tab-group` - Tab group indicator
- `.tab-position:not(.is-pinned) .tab-indicator` - Stacked tab indicators
- `.tab-position:not(.is-pinned) .tab .tab-header` - **MAIN TARGET** for height

### Tab Padding Control
- `.tab .title` - Uses `--phi--tab-padding` (left/right)
- `.tab .tab-header` - Uses `--phi--tab-padding-x` and `--phi--tab-padding-y`

### Pinned Tabs
- `.is-pinned .tab-wrapper` - Uses `--phi--pinned-tab-max-height` and `--phi--pinned-tab-aspect-ratio`
- `.is-pinned .tab .tab-header` - Fixed `flex: 0 0 40px`

## CSS Variables We Control

### Design System - Spacing Scale (8px base)
```css
--phi--spacing-micro: 2                /* 2px - borders, tiny gaps */
--phi--spacing-tiny: 4                 /* 4px - tight spacing */
--phi--spacing-small: 8                /* 8px - standard gap */
--phi--spacing-medium: 12              /* 12px - comfortable spacing */
--phi--spacing-large: 16               /* 16px - section separation */
--phi--spacing-xl: 24                  /* 24px - major sections */
```

### User-Configurable (in phi-settings.css)

**Sidebar:**
```css
--phi--sidebar-width: 344              /* Sidebar width */
--phi--sidebar-padding: 8              /* Internal padding */
--phi--compact-sidebar-width: 50       /* Compact mode width */
```

**Tabs:**
```css
--phi--tab-height: 48                  /* Normal tab height */
--phi--tab-spacing: 8                  /* Gap between tabs */
--phi--tab-padding-x: 12               /* Horizontal padding in tab */
--phi--tab-padding-y: 8                /* Vertical padding in tab */
--phi--tab-border-radius: 8            /* Tab corner radius */
--phi--pinned-column-count: 4          /* Pinned tabs columns */
```

**Buttons:**
```css
--phi--button-size: 32                 /* Button width/height */
--phi--button-border-radius: 8         /* Button corner radius */
--phi--button-margin: 8                /* Spacing around buttons */
--phi--button-padding: 4               /* Internal button padding */
```

**Pinned Tabs:**
```css
--phi--pinned-tab-max-height: 64       /* Max height for pinned tabs */
--phi--pinned-tab-aspect-ratio: 1.2    /* Aspect ratio for pinned tabs */
--phi--pinned-tab-border-radius: 8     /* Pinned tab corner radius */
```

**Transitions:**
```css
--phi--transition-speed: 0.2s          /* Animation duration */
--phi--hover-scale-small: 1.02         /* Small hover scale */
--phi--hover-scale-medium: 1.05        /* Medium hover scale */
--phi--hover-lift: -2                  /* Hover lift distance (px) */
```

**Webview:**
```css
--phi--webview-border-radius: 8        /* Border radius for webview */
--phi--webview-shadow-size: 12         /* Shadow size for webview */
```

**Toolbar:**
```css
--phi--toolbar-column-count: 5         /* Address bar columns */
```

### Internal (calculated by theme)
```css
--phi___is-compact-mode: 0/1           /* Auto-calculated compact state */
--phi___is-panel-open: 0/1             /* Panel open state */
--phi___is-panel-closed: 0/1           /* Panel closed state */
--phi__sidebar-order: 1/2              /* Grid order for sidebar */
--phi__page-order: 1/2                 /* Grid order for page */
--phi__address-bar-row: 2/3            /* Address bar grid row */
--phi__extensions-row: 3/4             /* Extensions grid row */
```

## Current Spacing System

### Gaps & Margins
- Tab strip gap: `calc(var(--phi--tab-spacing, 8) * 1px)` → 4px (from settings)
- Tab strip padding: `4px 0`
- Toolbar/container padding: `0 8px`
- Workspace button margin: `0 8px 8px 8px`
- Extension button margin: `2px`

### Padding
- Tab header: `calc(var(--phi--tab-padding-y) * 1px) calc(var(--phi--tab-padding-x) * 1px)` → 8px 8px
- Tab title: `calc(var(--phi--tab-padding) * 1px)` left/right → 16px (legacy, might conflict)

### Heights
- Normal tab: `calc(var(--phi--tab-height, 40) * 1px)` → 48px (from settings)
- Tab group: `calc(var(--phi--tab-height, 40) * 1px + 1px)` → 49px
- Tab header: `flex: 0 0 calc(var(--phi--tab-height, 40) * 1px)` → 48px
- Extension buttons: `34px`
- Pinned tabs: `max-height: calc(var(--phi--pinned-tab-max-height, 70) * 1px)` → 70px

### Widths
- Sidebar: `calc(var(--phi--sidebar-width) * 1px)` → 340px
- Compact sidebar: `calc(var(--phi--compact-sidebar-width) * 1px)` → 50px

## Known Issues

1. **Tab height not responding**: `.tab-position` has inline `--Height: 33px` that we override, but Vivaldi might recalculate it
2. **Padding conflict**: Both `--phi--tab-padding` (16px) and `--phi--tab-padding-x/y` (8px) exist
3. **Important flags**: Currently using `!important` on `.tab-position` height properties

## Questions for User

1. Should we remove `--phi--tab-padding` and only use `--phi--tab-padding-x/y`?
2. What spacing unit should we standardize on? (4px, 8px base?)
3. Do you want consistent border-radius everywhere?
4. Should all hover effects use the same scale/transform values?

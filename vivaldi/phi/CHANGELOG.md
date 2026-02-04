# Phi Custom CSS - Changelog

## Enhanced Version (2026-02-03)

### 🔧 Update 2 - Settings File Fix
- **Fixed phi-settings.css import order**: Import now comes AFTER :root defaults, allowing proper override
- **Changed selector**: Updated phi-settings.css to use `:root` instead of `body` for proper CSS custom property inheritance
- **File location**: Moved phi-settings.css to correct location (phi/ directory)
- **Now working**: All custom variables including `--phi--tab-padding` now properly override defaults

## Enhanced Version (2026-02-03) - Initial Release

### 🎨 Major Improvements

#### Tab Enhancements
- **Increased tab height**: 30px → 40px for better readability and touch targets
- **Enhanced padding**: Increased from 10px to 12px for more breathing room
- **Improved spacing**: Tab gaps increased from 5px to 8px
- **Optimized pinned tabs**: 
  - Reduced from square (1:1) to 1.2 aspect ratio for more compact design
  - Max height set to 70px (was unlimited)
  - Favicon size optimized to 20px
  - Added border-radius (8px) for modern look
  - Hover lift effect (-2px translateY) with shadow
  - Reduced hover scale from 1.05x to 1.03x for subtlety
- **Smooth transitions**: Added 0.2s ease transitions for all interactive elements
- **Better hover effects**: 
  - Subtle scale animation (1.02x) on hover
  - Smooth transform with 2px slide on group hover
  - Font weight increase on hover for better visual feedback
- **Modern border radius**: Consistent 6px radius for cleaner look
- **Active tab shadow**: Subtle shadow (0 2px 8px) for better depth perception

#### Sidebar & Layout
- **Wider sidebar**: 320px → 340px for more comfortable reading
- **Increased padding**: Toolbar and container padding from 5px to 8px
- **Better webview styling**:
  - Border radius: 0 → 8px
  - Shadow size: 0 → 12px
  - Refined shadow color for subtlety

#### UI Elements
- **Extension buttons**: 
  - Size increased: 30px → 34px
  - Added 2px margin for better separation
  - Scale animation (1.1x) on hover
  - Hover shadow for depth
- **Workspace button**:
  - Enhanced margins (8px)
  - Lift animation on hover (-1px translateY)
  - Subtle shadow on hover
- **Address bar**:
  - Smooth transitions
  - Focus shadow (0 2px 12px) for better focus indication
  - Font size increased from 12px to 13px for tab indicators

#### Performance Optimizations
- **Hardware acceleration**: Added `will-change` and `backface-visibility` for smooth animations
- **Font smoothing**: Enabled antialiasing for better text rendering
- **Smooth scrolling**: Added `scroll-behavior: smooth` for tab strip

#### Visual Polish
- **Consistent transitions**: All interactive elements now have 0.2s ease transitions
- **Better depth hierarchy**: Strategic use of shadows and transforms
- **Improved hover states**: All clickable elements have clear hover feedback
- **New tab button**: Added scale and shadow on hover

### 📝 New CSS Variables
```css
--phi--tab-height: 40                    /* Customizable tab height */
--phi--tab-spacing: 8                    /* Gap between tabs */
--phi--tab-padding: 12                   /* Internal tab padding */
--phi--transition-speed: 0.2s            /* Global transition duration */
--phi--pinned-tab-max-height: 70         /* Maximum height for pinned tabs */
--phi--pinned-tab-aspect-ratio: 1.2      /* Aspect ratio for pinned tabs (width:height) */
```

### 🔧 Modified Variables
```css
--phi--sidebar-width: 320 → 340
--phi--webview-border-radius: 0 → 8
--phi--webview-shadow-size: 0 → 12
--phi--webview-shadow-color: 0,0,0,0.25 → 0,0,0,0.15
```

### 💾 Backup
Original file backed up as: `custom.css.backup`

### 🎯 Benefits
- **Better UX**: More comfortable clicking and reading
- **Modern design**: Smooth animations and subtle depth
- **Performance**: Hardware-accelerated animations
- **Customizable**: New CSS variables for easy tweaking
- **Accessibility**: Larger touch targets and better visual feedback

### 🔄 Reverting Changes
To restore the original:
```bash
cp custom.css.backup custom.css
```

### 🎨 Further Customization
You can adjust the new variables in the `:root` section:
- Increase `--phi--tab-height` for even taller tabs
- Adjust `--phi--tab-spacing` for more/less gap between tabs
- Modify `--phi--tab-padding` for different internal spacing
- Change `--phi--transition-speed` for faster/slower animations

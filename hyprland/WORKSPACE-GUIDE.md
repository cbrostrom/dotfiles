# 🪟 Hyprland Workspace Guide

Complete workspace layout and window management guide.

---

## 📋 Workspace Layout

### **Dell Monitor (DP-4) - Left**
| Workspace | Name | Purpose | Apps |
|-----------|------|---------|------|
| **1** | default | Terminal & Dev | Ghostty |
| **2** | browser | Web Browsing | Vivaldi, Chrome, Firefox |
| **4** | comms | Communication | Slack, Teams, Outlook, Betterbird, Beeper, Discord |
| **7** | misc-dell | Catch-all | Unmapped windows |

### **ASUS Monitor (DP-1) - Right (Gaming)**
| Workspace | Name | Purpose | Apps |
|-----------|------|---------|------|
| **3** | default | Code Editor | Cursor |
| **5** | gaming-launchers | Game Launchers | Steam, Lutris, Heroic, Bottles, Ubisoft Connect |
| **6** | media | Music & Video | Spotify, VLC, MPV |
| **8** | misc-asus | Catch-all | Unmapped windows |
| **9** | gaming-active | Active Games | Running games (optimized) |

---

## 🎮 Gaming Workflow

### **Workspace 5: Game Launchers**
- Steam library
- Lutris
- Heroic Games Launcher
- Bottles
- Ubisoft Connect launcher
- EA App / Origin launcher

**Purpose:** Browse games, manage library, configure settings

### **Workspace 9: Active Gaming**
- Actual game windows
- Optimized for performance:
  - No gaps
  - No borders
  - No rounding
  - Immediate rendering
  - No animations

**Purpose:** Play games with max FPS

### **How It Works:**
1. Open Steam on workspace 5
2. Launch a game
3. Game window automatically goes to workspace 9
4. Fullscreen games lock mouse automatically
5. ALT+TAB back to workspace 5 to see Steam overlay/friends

---

## 🗂️ Catch-All Workspaces (7 & 8)

### **Purpose:**
For windows that don't have specific workspace assignments:
- New apps you install
- Temporary windows
- One-off applications
- Testing

### **How To Use:**
1. New window opens on workspace 7 or 8
2. You can manually move it: `SUPER + SHIFT + [1-9]`
3. If you want it permanent, tell me the app and I'll add a rule

### **Examples:**
- File manager (Dolphin, Nautilus)
- Image viewers
- PDF readers
- Random GUI apps

---

## 🔄 Monitor Fallback

**If ASUS monitor is off:**
- All workspaces fall back to Dell monitor
- You can still access workspace 3, 5, 6, 8, 9 on Dell

**If Dell monitor is off:**
- All workspaces fall back to ASUS monitor
- You can still access workspace 1, 2, 4, 7 on ASUS

**Hyprland automatically handles this!**

---

## ⌨️ Workspace Keybinds

### **Switch to Workspace:**
```
SUPER + [1-9]       → Switch to workspace 1-9
```

### **Move Window to Workspace:**
```
SUPER + SHIFT + [1-9]   → Move active window to workspace
```

### **Move Workspace to Other Monitor:**
```
SUPER + SHIFT + O       → Move current workspace to other monitor
```

### **Reset Workspaces:**
```
SUPER + SHIFT + R       → Reset all workspaces to default monitors
```

---

## 🎯 Common Workflows

### **Gaming Session:**
1. `SUPER + 5` - Open Steam (workspace 5)
2. Launch game
3. Game opens on workspace 9 automatically
4. Go fullscreen for locked mouse
5. `SUPER + 5` - Back to Steam for friends/overlay

### **Work Session:**
1. `SUPER + 1` - Terminal (Ghostty)
2. `SUPER + 2` - Browser (Vivaldi)
3. `SUPER + 3` - Code (Cursor)
4. `SUPER + 4` - Communication (Slack, Teams)

### **Media Session:**
1. `SUPER + 6` - Music (Spotify)
2. `SUPER + 2` - YouTube (Vivaldi)

---

## 🔧 Adding New Apps

### **Method 1: Tell Me**
Just say: "Hey, add [app] to workspace [X]"

### **Method 2: Find Window Class**
1. Open the app
2. Run: `hyprctl clients | grep -i "appname"`
3. Find the `class:` line
4. Add to `~/.config/hypr/hyprland.conf`:

```hyprlang
windowrule {
  name = myapp_workspace
  match:class = ^(app-class)$
  workspace = X silent
}
```

### **Method 3: Temporary Manual Move**
1. Open app
2. `SUPER + SHIFT + [1-9]` to move to desired workspace
3. If you want it permanent, tell me!

---

## 📊 Current Workspace Assignments

### **Productivity**
- Ghostty → Workspace 1 (Dell)
- Vivaldi → Workspace 2 (Dell)
- Cursor → Workspace 3 (ASUS)

### **Communication**
- Slack → Workspace 4 (Dell)
- Teams → Workspace 4 (Dell)
- Outlook → Workspace 4 (Dell)
- Betterbird → Workspace 4 (Dell)
- Beeper → Workspace 4 (Dell)
- Discord → Workspace 4 (Dell)

### **Gaming**
- Steam (launcher) → Workspace 5 (ASUS)
- Lutris → Workspace 5 (ASUS)
- Heroic → Workspace 5 (ASUS)
- Bottles → Workspace 5 (ASUS)
- Ubisoft Connect → Workspace 5 (ASUS)
- EA App → Workspace 5 (ASUS)
- **Game windows** → **Workspace 9 (ASUS)** ⭐

### **Media**
- Spotify → Workspace 6 (ASUS)
- VLC → Workspace 6 (ASUS)
- MPV → Workspace 6 (ASUS)

### **Misc**
- Unmapped apps → Workspace 7 (Dell) or 8 (ASUS)

---

## 💡 Pro Tips

### **Gaming:**
1. Keep Steam on workspace 5 (visible)
2. Games auto-go to workspace 9 (optimized)
3. Use fullscreen for locked mouse
4. `SUPER + 9` to see game, `SUPER + 5` to see Steam

### **Multi-Monitor:**
- Dell (left) = Work/Communication
- ASUS (right) = Code/Gaming/Media

### **Catch-All:**
- New apps go to workspace 7 or 8
- Manually organize them
- Tell me if you want them permanent

---

## 🔍 Debugging

### **Check Window Class:**
```bash
hyprctl clients | grep -i "appname"
```

### **Check Current Workspace:**
```bash
hyprctl activeworkspace
```

### **List All Windows:**
```bash
hyprctl clients
```

---

**Your workspace setup is now a well-organized, air-traffic-control style system!** ✈️🎮

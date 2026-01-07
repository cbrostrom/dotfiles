# Linux-Specific Configurations

This directory contains Linux-specific configurations and scripts, with a focus on Hyprland window manager setup.

## 📁 Structure

```
linux/
├── hyprland/              # Hyprland window manager
│   ├── hyprland.conf      # Main Hyprland configuration
│   └── hyprpaper.conf     # Wallpaper daemon config
│
├── waybar/                # Status bar
│   ├── config.jsonc       # Waybar modules and layout
│   └── style.css          # Waybar styling (Catppuccin dark theme)
│
├── interception/          # Keyboard remapping
│   ├── dual-function-keys.yaml  # Caps Lock dual-function config
│   └── udevmon.yaml             # Interception daemon config
│
└── install-hyprland.sh    # Installation script
```

## 🚀 Quick Start

### Full Hyprland Setup

```bash
cd ~/dotfiles/linux
./install-hyprland.sh
```

This will:
- Install Hyprland and dependencies
- Install Waybar (status bar)
- Install Vicinae (Raycast-like launcher)
- Configure keyboard remapping (Caps Lock → Esc/Super)
- Create symlinks to configs
- Update `.local-config`

### Manual Installation

If you prefer to install components separately:

```bash
# Arch/CachyOS
sudo pacman -S hyprland hyprpaper waybar polkit-kde-agent
yay -S interception-tools interception-dual-function-keys vicinae

# Symlink configs
ln -sf ~/dotfiles/linux/hyprland/hyprland.conf ~/.config/hypr/hyprland.conf
ln -sf ~/dotfiles/linux/hyprland/hyprpaper.conf ~/.config/hypr/hyprpaper.conf
ln -sf ~/dotfiles/linux/waybar ~/.config/waybar

# Setup interception
sudo cp ~/dotfiles/linux/interception/dual-function-keys.yaml /etc/interception/
sudo cp ~/dotfiles/linux/interception/udevmon.yaml /etc/interception/udevmon.d/caps-to-esc-super.yaml
sudo systemctl enable --now udevmon
```

## 🎨 Hyprland Configuration

### Vicinae Launcher

Vicinae is a Raycast-like launcher for Hyprland with:
- **App launching**: Quick access to all applications
- **Calculator**: Built-in calculator
- **System commands**: Logout, shutdown, restart
- **Fast and responsive**: Written in Rust

Press `SUPER+R` or `ALT+SPACE` to open Vicinae.

### Workspace Layout

| Workspace | Purpose | Apps |
|-----------|---------|------|
| WS1 | Web | Microsoft Edge |
| WS2 | Code | Cursor IDE |
| WS3 | Terminal | Kitty, Alacritty, Ghostty |
| WS4 | Comms | Slack, Teams, Mail, Calendar |
| WS5 | Gaming | Steam |

### Keybindings

| Key | Action |
|-----|--------|
| `SUPER+B` | Browser (WS1) |
| `SUPER+E` | Cursor IDE (WS2) |
| `SUPER+Q` | Terminal (WS3) |
| `SUPER+SHIFT+S` | Slack (WS4) |
| `SUPER+T` | Teams (WS4) |
| `SUPER+G` | Steam (WS5) |
| `SUPER+R` or `ALT+SPACE` | Launcher (Vicinae) |
| `SUPER+F` | File Manager (Dolphin) |
| `SUPER+C` | Close Window |
| `SUPER+V` | Toggle Floating |
| `SUPER+1-5` | Switch Workspace |
| `CAPS LOCK` | **Tap:** Escape, **Hold:** Super key |

## 🎯 Waybar Features

- **Workspaces**: Icon-based with color coding
  - 🌐 WS1 (Web) - Blue
  - 💻 WS2 (Code) - Green
  - 📟 WS3 (Terminal) - Yellow
  - 💬 WS4 (Comms) - Purple
  - 🎮 WS5 (Gaming) - Pink

- **System Monitors**: CPU, Memory, Temperature
- **Network**: WiFi/Ethernet status
- **Audio**: Volume control (scroll to adjust)
- **Clock**: Click to toggle date format
- **System Tray**: Running apps
- **Power Menu**: Logout/shutdown (wlogout)

### Theme

Waybar uses a **Catppuccin-inspired dark theme** with:
- Translucent backgrounds
- Rounded corners
- Color-coded elements
- Nerd Font icons

## ⌨️ Caps Lock Dual-Function

The interception setup provides:

- **Short press** → **Escape** (perfect for Vim/modal editing)
- **Hold + key** → **Super + key** (window manager commands)

### Examples

```
Tap Caps Lock          → Esc
Hold Caps + E          → SUPER+E (open Cursor)
Hold Caps + Q          → SUPER+Q (open Terminal)
Hold Caps + 1          → SUPER+1 (switch to WS1)
```

This means you can use Caps Lock as your main modifier key, reducing hand movement!

## 🔧 Customization

### Change Wallpaper

Edit `hyprland/hyprpaper.conf`:

```conf
preload = /path/to/your/wallpaper.png
wallpaper = ,/path/to/your/wallpaper.png
```

Available CachyOS wallpapers: `/usr/share/wallpapers/cachyos-wallpapers/`

### Modify Workspace Layout

Edit `hyprland/hyprland.conf` in the "WORKSPACE APP RULES" section:

```conf
windowrulev2 = workspace 1 silent,class:^(yourapp)$
```

### Customize Waybar

- **Layout**: Edit `waybar/config.jsonc`
- **Styling**: Edit `waybar/style.css`
- **Icons**: Uses Nerd Font glyphs (search: https://www.nerdfonts.com/cheat-sheet)

Restart waybar: `killall waybar && waybar &`

## 🐛 Troubleshooting

### Waybar icons not showing

```bash
# Install Nerd Fonts
sudo pacman -S ttf-jetbrains-mono-nerd ttf-font-awesome

# Reload waybar
killall waybar && waybar &
```

### Caps Lock remapping not working

```bash
# Check service status
sudo systemctl status udevmon

# Restart service
sudo systemctl restart udevmon

# View logs
journalctl -u udevmon -f
```

### Apps not opening on correct workspace

Window rules only apply to **new windows**. Close and reopen the app.

For persistent issues, check the app's class:
```bash
hyprctl clients | grep -A 5 "your-app-name"
```

Then update the rule in `hyprland.conf`.

## 📚 Resources

- [Hyprland Wiki](https://wiki.hyprland.org/)
- [Waybar Documentation](https://github.com/Alexays/Waybar/wiki)
- [Interception Tools](https://gitlab.com/interception/linux/tools)
- [Nerd Fonts Cheat Sheet](https://www.nerdfonts.com/cheat-sheet)

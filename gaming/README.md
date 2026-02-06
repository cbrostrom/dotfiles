# 🎮 Gaming Setup

Complete gaming configuration for Linux with Hyprland, optimized for RTX 2070 SUPER.

## 📋 Overview

This gaming setup includes:
- **Gamemode** - CPU/GPU performance boost
- **MangoHud** - Performance overlay
- **Gamescope** - Resolution scaling with FSR
- **Game Launcher** - Unified launch wrapper with presets
- **Hyprland Integration** - Dedicated gaming workspace with optimizations

---

## 🚀 Quick Start

### Install Gaming Tools

```bash
# Core gaming tools (should already be installed)
sudo pacman -S gamemode lib32-gamemode mangohud lib32-mangohud gamescope

# Add yourself to gamemode group
sudo usermod -aG gamemode $USER

# Reboot to apply group changes
reboot
```

### Setup Configs

Configs are automatically symlinked from dotfiles:

```bash
~/.config/game-launcher/presets.conf -> ~/.config/dotfiles/gaming/config/presets.conf
~/.config/MangoHud/MangoHud.conf     -> System config
~/bin/gamelaunch                      -> ~/.config/dotfiles/gaming/bin/gamelaunch
```

---

## 🎯 Usage

### Steam Launch Options

**Right-click game → Properties → General → Launch Options**

**For demanding games (1080p upscaled to 1440p):**
```bash
gamelaunch --preset nvidia-1080p %command%
```

**For competitive games:**
```bash
gamelaunch --preset competitive %command%
```

**For lighter games (native 1440p):**
```bash
gamelaunch --preset nvidia-native %command%
```

**With Gamescope FSR (best upscaling quality):**
```bash
gamescope -W 2560 -H 1440 -w 1920 -h 1080 -f -r 144 --fsr-sharpness 5 -- gamelaunch --preset gamescope-1080p %command%
```

See [STEAM-LAUNCH-OPTIONS.md](STEAM-LAUNCH-OPTIONS.md) for complete guide.

---

## 📚 Available Presets

### Resolution Scaling (RTX 2070 SUPER)

| Preset | Description | Use Case |
|--------|-------------|----------|
| `nvidia-1080p` | 1080p upscaled to 1440p | Demanding AAA games |
| `gamescope-1080p` | FSR Quality upscaling | Best upscaling quality |
| `gamescope-1080p-balanced` | FSR Balanced | Balance quality/performance |
| `gamescope-1080p-performance` | FSR Performance | Maximum FPS |
| `nvidia-native` | Native 1440p | Lighter games |

### Performance Presets

| Preset | Description |
|--------|-------------|
| `default` | Gamemode + MangoHud with basic stats |
| `performance` | Maximum performance, minimal overlay |
| `competitive` | Optimized for competitive games |
| `minimal` | Gamemode only, no overlay |
| `capped60` | Limit to 60 FPS |
| `capped120` | Limit to 120 FPS |

### Game-Specific Presets

| Preset | Game | Notes |
|--------|------|-------|
| `diablo4` | Diablo IV | VRAM optimized for NVIDIA |
| `poe2` | Path of Exile 2 | DX12 optimized |
| `lastepoch` | Last Epoch | VRAM fixes |
| `division2` | The Division 2 | EasyAntiCheat support |
| `avatar-pandora` | Avatar: Frontiers of Pandora | GE-Proton optimized |

### Utility Presets

| Preset | Description |
|--------|-------------|
| `debug` | Full logging for troubleshooting |
| `streaming` | Optimized for OBS/streaming |
| `compatibility` | For problematic games |

---

## 🖥️ Hyprland Integration

### Gaming Workspace (Workspace 5)

All gaming apps automatically launch on **Workspace 5** on the **ASUS monitor (DP-1)**:
- Steam
- Lutris
- Heroic Games Launcher
- Bottles
- Game windows

### Gaming Optimizations

Configured in `~/.config/hypr/hyprland.conf`:

```hyprlang
# Gaming workspace
workspace = 5, monitor:DP-1, name:gaming, default:false, persistent:true

# Gaming apps auto-launch on workspace 5
windowrule { name = steam_gaming; match:class = ^(steam)$; workspace = 5 silent }

# Gaming optimizations
windowrule { name = fullscreen_game_optimize; match:fullscreen = 1; workspace = 5; immediate = on; rounding = 0 }

# Steam chat windows float
windowrule { name = steam_friends_float; match:title = ^(Friends List)$; float = on; size = 400 700 }
windowrule { name = steam_chat_float; match:title = ^(Steam - ); float = on; size = 500 600 }
```

**Features:**
- No window rounding for fullscreen games (better performance)
- Immediate rendering (no animations)
- Persistent workspace (survives reboots)
- Steam chat windows automatically float

---

## 🎮 MangoHud

### Controls

| Key | Action |
|-----|--------|
| **F12** | Toggle overlay on/off |
| **Shift+F2** | Start/stop performance logging |
| **Shift+F4** | Reload config |

### Config Location

```
~/.config/MangoHud/MangoHud.conf
```

### What's Displayed

- FPS and frame timing
- GPU stats (temp, clock, power, load, VRAM)
- CPU stats (temp, clock, power, per-core load)
- RAM and SWAP usage
- Resolution
- Vulkan driver info
- Wine/Proton version

### Custom Config Per-Game

Override in Steam launch options:

```bash
MANGOHUD_CONFIG=fps_only,position=top-right,font_size=32 gamelaunch --preset nvidia-1080p %command%
```

---

## 🔧 Gamemode

### Check Status

```bash
# Check if gamemode is active
gamemoded -s

# Should show: "gamemode is active"
```

### What It Does

When a game launches with `gamemoderun`:
- Sets CPU governor to `performance`
- Increases process priority
- Disables CPU frequency scaling
- Optimizes I/O scheduler
- Reduces input latency

---

## 🎯 Gamescope

### What Is It?

Gamescope is a micro-compositor that:
- Provides native resolution scaling
- Implements AMD FSR upscaling
- Fixes VRR/FreeSync issues
- Provides better frame pacing

### Basic Usage

```bash
gamescope -W 2560 -H 1440 -w 1920 -h 1080 -f -r 144 -- %command%
```

**Flags:**
- `-W` / `-H` - Output resolution (monitor)
- `-w` / `-h` - Game render resolution
- `-f` - Fullscreen
- `-r` - Refresh rate
- `--fsr-sharpness 0-20` - FSR sharpening

### FSR Modes

**Quality (best quality):**
```bash
gamescope -W 2560 -H 1440 -w 1920 -h 1080 -f -r 144 --fsr-sharpness 5 -- %command%
```

**Balanced:**
```bash
gamescope -W 2560 -H 1440 -w 1920 -h 1080 -f -r 144 --fsr-sharpness 3 -- %command%
```

**Performance (max FPS):**
```bash
gamescope -W 2560 -H 1440 -w 1920 -h 1080 -f -r 144 --fsr-sharpness 2 -- %command%
```

---

## 📊 Expected Performance (RTX 2070 SUPER)

### Native 1440p

| Game Type | Settings | FPS |
|-----------|----------|-----|
| AAA (2023+) | Ultra | 40-60 |
| AAA (2023+) | High | 60-80 |
| AAA (2020-2022) | Ultra | 60-90 |
| Competitive | Low | 144+ |
| Indie | Max | 144+ |

### 1080p Upscaled

| Game Type | Settings | FPS |
|-----------|----------|-----|
| AAA (2023+) | Ultra | 60-90 |
| AAA (2023+) | High | 90-120 |
| AAA (2020-2022) | Ultra | 90-144 |
| Competitive | Low | 200+ |
| Indie | Max | 144+ |

**Tip:** Use 1080p upscaling for demanding games to maintain 60+ FPS.

---

## 🐛 Troubleshooting

### Gamemode not working

```bash
# Check service status
systemctl --user status gamemoded

# Check if you're in gamemode group
groups | grep gamemode

# If not, add yourself and reboot
sudo usermod -aG gamemode $USER
reboot
```

### MangoHud not showing

```bash
# Test with glxgears
mangohud glxgears

# If not working, reinstall
sudo pacman -S mangohud lib32-mangohud

# Force enable in Steam
MANGOHUD=1 %command%
```

### Low FPS

1. **Use 1080p upscaling:**
   ```bash
   gamelaunch --preset nvidia-1080p %command%
   ```

2. **Lower in-game settings:**
   - Shadows: Medium/Low
   - Anti-aliasing: TAA
   - Ray tracing: Off

3. **Check GPU usage in MangoHud:**
   - Should be 90-100%
   - If lower, CPU bottleneck

### Game crashes

**Try compatibility mode:**
```bash
gamelaunch --preset compatibility %command%
```

**Use different Proton version:**
- Right-click game → Properties → Compatibility
- Try: Proton Experimental, GE-Proton, Proton 8.0

**Check logs:**
```bash
tail -f ~/.config/game-launcher/launch.log
```

---

## 📂 File Structure

```
~/.config/dotfiles/gaming/
├── bin/
│   └── gamelaunch                    # Main launch wrapper
├── config/
│   └── presets.conf                  # Game launch presets
├── game-desktop-sync/                # Auto-create .desktop files
│   ├── game-desktop-sync.sh
│   ├── game-desktop-sync.service
│   └── game-desktop-sync.timer
├── dxvk-configs/                     # DXVK optimizations
├── README.md                         # This file
└── STEAM-LAUNCH-OPTIONS.md          # Complete Steam guide
```

---

## 🔗 Useful Resources

- **ProtonDB** - Game compatibility: https://www.protondb.com/
- **Proton GE** - Community Proton builds: https://github.com/GloriousEggroll/proton-ge-custom
- **MangoHud** - Performance overlay: https://github.com/flightlessmango/MangoHud
- **Gamemode** - Performance daemon: https://github.com/FeralInteractive/gamemode
- **Gamescope** - Gaming compositor: https://github.com/ValveSoftware/gamescope

---

## 🎯 Next Steps

1. **Test your setup:**
   ```bash
   # Launch a game with the default preset
   gamelaunch --preset nvidia-1080p %command%
   ```

2. **Monitor performance:**
   - Press **F12** to toggle MangoHud
   - Check GPU usage, temps, and FPS

3. **Adjust settings:**
   - If FPS is low, use 1080p upscaling
   - If FPS is high, try native 1440p
   - Tweak in-game settings

4. **Read the full guide:**
   - See [STEAM-LAUNCH-OPTIONS.md](STEAM-LAUNCH-OPTIONS.md)

---

**Happy gaming! 🎮**

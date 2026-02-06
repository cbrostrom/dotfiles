# 🎮 Steam Launch Options Guide

Complete guide for optimizing Steam games on Linux with RTX 2070 SUPER.

## 📋 Table of Contents

- [Quick Start](#quick-start)
- [Resolution Scaling](#resolution-scaling)
- [Preset Reference](#preset-reference)
- [Per-Game Examples](#per-game-examples)
- [Troubleshooting](#troubleshooting)

---

## 🚀 Quick Start

### Basic Usage

**Right-click game in Steam → Properties → General → Launch Options**

### Recommended Presets

**For demanding games (Cyberpunk, Witcher 3, etc.):**
```bash
gamelaunch --preset nvidia-1080p %command%
```

**For competitive games (CS2, Valorant, etc.):**
```bash
gamelaunch --preset competitive %command%
```

**For lighter games (indie, older games):**
```bash
gamelaunch --preset nvidia-native %command%
```

---

## 🖥️ Resolution Scaling

Your RTX 2070 SUPER is great but aging. Running demanding games at 1080p upscaled to 1440p gives **30-50% better FPS** with minimal quality loss.

### Method 1: Simple (Recommended)

**Launch Options:**
```bash
gamelaunch --preset nvidia-1080p %command%
```

**In-game settings:**
- Set resolution to **1920x1080**
- Set to **Fullscreen** (not windowed)
- Enable game's built-in upscaling if available (DLSS, FSR, etc.)

### Method 2: Gamescope FSR (Best Quality)

**For FSR Quality mode (best quality):**
```bash
gamescope -W 2560 -H 1440 -w 1920 -h 1080 -f -r 144 --fsr-sharpness 5 -- gamelaunch --preset gamescope-1080p %command%
```

**For FSR Balanced mode (balanced):**
```bash
gamescope -W 2560 -H 1440 -w 1920 -h 1080 -f -r 144 --fsr-sharpness 3 -- gamelaunch --preset gamescope-1080p-balanced %command%
```

**For FSR Performance mode (max FPS):**
```bash
gamescope -W 2560 -H 1440 -w 1920 -h 1080 -f -r 144 --fsr-sharpness 2 -- gamelaunch --preset gamescope-1080p-performance %command%
```

**Gamescope flags explained:**
- `-W 2560 -H 1440` - Output resolution (your monitor)
- `-w 1920 -h 1080` - Game render resolution
- `-f` - Fullscreen
- `-r 144` - Refresh rate (your ASUS monitor)
- `--fsr-sharpness 0-20` - Sharpening (5=balanced, 10=sharp, 20=very sharp)

### Method 3: Native 1440p (Lighter Games)

**Launch Options:**
```bash
gamelaunch --preset nvidia-native %command%
```

**In-game settings:**
- Set resolution to **2560x1440**
- Use native resolution for best quality

---

## 📚 Preset Reference

### Resolution Presets

| Preset | Use Case | MangoHud | Resolution |
|--------|----------|----------|------------|
| `nvidia-1080p` | Demanding games, upscaled | ✅ | 1080p → 1440p |
| `gamescope-1080p` | Best upscaling quality (FSR) | ❌ | 1080p → 1440p |
| `nvidia-native` | Lighter games, full quality | ✅ | Native 1440p |

### Performance Presets

| Preset | Use Case | GameMode | MangoHud |
|--------|----------|----------|----------|
| `default` | General gaming | ✅ | ✅ |
| `performance` | Maximum FPS | ✅ | Minimal |
| `competitive` | Competitive games | ✅ | FPS only |
| `minimal` | No overlay | ✅ | ❌ |

### Game-Specific Presets

| Preset | Game | Notes |
|--------|------|-------|
| `diablo4` | Diablo IV | VRAM optimized |
| `poe2` | Path of Exile 2 | DX12 optimized |
| `lastepoch` | Last Epoch | VRAM fixes |
| `avatar-pandora` | Avatar: Frontiers of Pandora | Use GE-Proton 10-28+ |

### Special Presets

| Preset | Use Case |
|--------|----------|
| `capped60` | Limit to 60 FPS |
| `capped120` | Limit to 120 FPS |
| `streaming` | OBS/streaming optimized |
| `debug` | Full logging for troubleshooting |

---

## 🎯 Per-Game Examples

### Cyberpunk 2077

**Demanding game, needs upscaling:**

```bash
gamescope -W 2560 -H 1440 -w 1920 -h 1080 -f -r 144 --fsr-sharpness 5 -- gamelaunch --preset gamescope-1080p %command%
```

**In-game:**
- Resolution: 1920x1080
- DLSS: Quality (if available)
- Ray Tracing: Medium or Off

### The Witcher 3

**Moderate demands:**

```bash
gamelaunch --preset nvidia-1080p %command%
```

**In-game:**
- Resolution: 1920x1080
- Fullscreen
- Graphics: High/Ultra

### CS2 / Counter-Strike 2

**Competitive, needs max FPS:**

```bash
gamelaunch --preset competitive %command%
```

**In-game:**
- Resolution: 1920x1080 or 1280x720 (for max FPS)
- All settings: Low
- Disable VSync

### Diablo IV

**ARPG with VRAM issues:**

```bash
gamelaunch --preset diablo4 %command%
```

**In-game:**
- Resolution: 1920x1080
- Texture Quality: Medium
- Use GE-Proton 10-28+

### Indie Games (Hades, Hollow Knight, etc.)

**Light games, native resolution:**

```bash
gamelaunch --preset nvidia-native %command%
```

**In-game:**
- Resolution: 2560x1440
- Max settings

---

## 🔧 Custom Launch Options

### Manual Environment Variables

If you don't want to use presets, you can set env vars directly:

```bash
DXVK_ASYNC=1 PROTON_ENABLE_NVAPI=1 gamemoderun mangohud %command%
```

### Common NVIDIA Optimizations

```bash
PROTON_ENABLE_NVAPI=1        # Enable NVIDIA API (DLSS, Reflex)
__GL_SHADER_DISK_CACHE_SKIP_CLEANUP=1  # Keep shader cache
VKD3D_CONFIG=dxr11,dxr       # DirectX Raytracing support
DXVK_ASYNC=1                 # Async shader compilation
```

### MangoHud Custom Config

```bash
MANGOHUD_CONFIG=fps_only,position=top-right,font_size=32 mangohud %command%
```

---

## 🎮 MangoHud Controls

| Key | Action |
|-----|--------|
| **F12** | Toggle overlay on/off |
| **Shift+F2** | Start/stop logging |
| **Shift+F4** | Reload config |

---

## 📊 Expected Performance (RTX 2070 SUPER)

### 1440p Native

| Game Type | Expected FPS |
|-----------|--------------|
| AAA (Ultra) | 40-60 FPS |
| AAA (High) | 60-80 FPS |
| Competitive | 100-144+ FPS |
| Indie | 144+ FPS |

### 1080p Upscaled

| Game Type | Expected FPS |
|-----------|--------------|
| AAA (Ultra) | 60-90 FPS |
| AAA (High) | 90-120 FPS |
| Competitive | 144+ FPS |
| Indie | 144+ FPS |

---

## 🐛 Troubleshooting

### Game won't start

**Try:**
```bash
gamelaunch --preset compatibility %command%
```

### Low FPS

1. **Use 1080p upscaling:**
   ```bash
   gamelaunch --preset nvidia-1080p %command%
   ```

2. **Lower in-game settings:**
   - Shadows: Medium/Low
   - Anti-aliasing: TAA or FXAA
   - Ambient Occlusion: Off/Low

3. **Check if gamemode is active:**
   ```bash
   gamemoded -s
   ```

### Stuttering

**Enable shader pre-caching in Steam:**
- Steam → Settings → Shader Pre-Caching → Enable

**Or use DXVK async:**
```bash
gamelaunch --preset nvidia-1080p %command%
```
(Already includes `DXVK_ASYNC=1`)

### VRAM issues (crashes, textures not loading)

**Use low VRAM preset:**
```bash
gamelaunch --preset lastepoch-lowvram %command%
```

**In-game:**
- Texture Quality: Medium/Low
- Reduce resolution to 1080p

### Black screen / won't launch

**Try Proton Experimental or GE-Proton:**
1. Right-click game → Properties → Compatibility
2. Select "Proton Experimental" or "GE-Proton"

**Debug with logs:**
```bash
gamelaunch --preset debug %command%
```

Check logs:
```bash
tail -f ~/.config/game-launcher/launch.log
```

### MangoHud not showing

**Check if installed:**
```bash
which mangohud
```

**Test manually:**
```bash
mangohud glxgears
```

**Force enable:**
```bash
MANGOHUD=1 gamelaunch --preset nvidia-1080p %command%
```

---

## 📝 Tips & Best Practices

### 1. Use Proton GE

Download from: https://github.com/GloriousEggroll/proton-ge-custom

**Why:**
- Better game compatibility
- Built-in fixes for many games
- EasyAntiCheat support
- Better performance

### 2. Enable Shader Pre-Caching

**Steam → Settings → Shader Pre-Caching → Enable**

Reduces stuttering in games.

### 3. Set Steam Launch Options Per-Game

Don't use global launch options. Set per-game for best results.

### 4. Monitor Performance

Use MangoHud to find the right balance:
- Press **F12** to toggle
- Watch GPU usage (should be 90-100%)
- Watch VRAM usage (should be < 7GB for RTX 2070 SUPER)

### 5. Update Drivers

Keep NVIDIA drivers updated:
```bash
sudo pacman -Syu nvidia-dkms
```

### 6. Test Different Proton Versions

Some games work better with specific Proton versions:
- **Proton Experimental** - Latest features
- **GE-Proton** - Community fixes
- **Proton 8.0** - Stable fallback

---

## 🔗 Useful Links

- **ProtonDB**: https://www.protondb.com/ - Game compatibility database
- **Proton GE**: https://github.com/GloriousEggroll/proton-ge-custom
- **MangoHud**: https://github.com/flightlessmango/MangoHud
- **Gamemode**: https://github.com/FeralInteractive/gamemode

---

## 📂 Config Files

| File | Purpose |
|------|---------|
| `~/.config/game-launcher/presets.conf` | Game launch presets |
| `~/.config/MangoHud/MangoHud.conf` | MangoHud overlay config |
| `~/.config/game-launcher/launch.log` | Launch debug logs |

---

**Made with ❤️ for Linux gaming on RTX 2070 SUPER**

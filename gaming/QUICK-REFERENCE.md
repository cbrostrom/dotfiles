# 🎮 Gaming Quick Reference

Ultra-quick cheat sheet for Steam launch options.

---

## 🚀 Most Common Launch Options

### Demanding AAA Games (Cyberpunk, Witcher 3, etc.)

**1080p upscaled to 1440p (Recommended):**
```bash
gamelaunch --preset nvidia-1080p %command%
```

**With Gamescope FSR (Best Quality):**
```bash
gamescope -W 2560 -H 1440 -w 1920 -h 1080 -f -r 144 --fsr-sharpness 5 -- gamelaunch --preset gamescope-1080p %command%
```

### Competitive Games (CS2, Valorant, etc.)

```bash
gamelaunch --preset competitive %command%
```

### Lighter Games (Indie, older games)

```bash
gamelaunch --preset nvidia-native %command%
```

---

## 📋 Quick Preset List

| Preset | Use For |
|--------|---------|
| `nvidia-1080p` | Demanding games (1080p→1440p) |
| `nvidia-native` | Light games (native 1440p) |
| `competitive` | CS2, Valorant, etc. |
| `diablo4` | Diablo IV |
| `poe2` | Path of Exile 2 |
| `capped60` | Limit to 60 FPS |
| `capped120` | Limit to 120 FPS |

---

## 🎯 In-Game Settings

### For 1080p Upscaling

1. Set resolution: **1920x1080**
2. Mode: **Fullscreen** (not windowed)
3. VSync: **Off** (let monitor handle it)

### For Native 1440p

1. Set resolution: **2560x1440**
2. Mode: **Fullscreen**
3. Graphics: **High/Ultra**

---

## 🔧 MangoHud Controls

| Key | Action |
|-----|--------|
| **F12** | Toggle overlay |
| **Shift+F2** | Start/stop logging |

---

## 📊 Expected FPS (RTX 2070 SUPER)

| Resolution | AAA Games | Competitive |
|------------|-----------|-------------|
| **1080p** | 60-90 FPS | 144+ FPS |
| **1440p** | 40-60 FPS | 100-144 FPS |

**Tip:** Use 1080p upscaling for 30-50% better FPS!

---

## 🐛 Quick Troubleshooting

**Low FPS?**
```bash
gamelaunch --preset nvidia-1080p %command%
```

**Game won't start?**
```bash
gamelaunch --preset compatibility %command%
```

**Stuttering?**
- Enable shader pre-caching in Steam settings
- Use `nvidia-1080p` preset (has DXVK_ASYNC)

---

## 📖 Full Guides

- **Complete guide:** [STEAM-LAUNCH-OPTIONS.md](STEAM-LAUNCH-OPTIONS.md)
- **Setup info:** [README.md](README.md)

---

**Copy-paste ready! 🎮**

# Game-Specific Configuration Guide

This guide covers optimal settings for specific popular games on Linux using the gamelaunch wrapper.

## 🎮 Supported Games

### Diablo 4

**Best Preset:** `diablo4` (NVIDIA) or `diablo4-amd` (AMD)

**Steam Launch Options:**
```bash
gamelaunch --preset diablo4 %command%
```

**Known Issues & Fixes:**
- **VRAM Leak on NVIDIA**: Use the DXVK config template (see DXVK Configs section below)
- **Shader Stuttering**: DXVK_ASYNC=1 helps (included in preset)
- **Recommended Proton**: Proton Experimental or GE-Proton 9.x+

**In-Game Settings:**
- Use FSR 2 upscaling instead of native resolution
- Reduce texture quality one tier below max to avoid VRAM spikes
- Turn off VSync for high refresh rates
- Disable ray tracing if unstable

**DXVK Configuration Required:**
```bash
# For NVIDIA cards (16GB VRAM example):
cp ~/.config/dotfiles/gaming/dxvk-configs/diablo4-nvidia.conf \
   ~/.local/share/Steam/steamapps/common/"Diablo IV"/dxvk.conf

# For AMD cards:
cp ~/.config/dotfiles/gaming/dxvk-configs/diablo4-amd.conf \
   ~/.local/share/Steam/steamapps/common/"Diablo IV"/dxvk.conf
```

---

### Path of Exile 2

**Best Preset:** `poe2`

**Steam Launch Options:**
```bash
gamelaunch --preset poe2 %command%
```

**Additional Setup:**
1. Force DirectX 12 renderer (Vulkan is unreliable):
   - Edit: `~/.local/share/Steam/steamapps/compatdata/2694490/pfx/drive_c/users/steamuser/Documents/My Games/Path of Exile 2/poe2_production_Config.ini`
   - Under `[DISPLAY]`, set: `renderer_type=DirectX12`

**Known Issues & Fixes:**
- **Black screen on launch**: Use DirectX 12 (see above)
- **Shader cache growth**: Can grow large, monitor SSD space
- **Recommended Proton**: Proton 9.0-3 or latest Proton-GE

**In-Game Settings (Steam Deck/Low-End):**
- Resolution: 1280×800 (Steam Deck) or native
- Upscale: Intel XeSS Balanced, or FSR Quality
- VSync: OFF
- Dynamic Resolution: OFF
- Texture Quality: Medium
- Shadows: Low
- Target FPS: 40-60

---

### The Division 2

**Best Preset:** `division2`

**Steam Launch Options:**
```bash
gamelaunch --preset division2 %command%
```

**Additional Setup:**
1. Install Proton EasyAntiCheat Runtime (Steam → Library → Tools)
2. Force DirectX 11 (DX12 crashes under Proton):
   - Edit: `~/Documents/My Games/Tom Clancy's The Division 2/state.cfg` (in Proton prefix)
   - Set: `dx12 = false`

**Known Issues & Fixes:**
- **EAC crashes**: Ensure EAC runtime is installed and path is correct
- **Initial stuttering**: Shader cache warmup takes ~1 hour
- **Recommended Proton**: Proton Experimental or GE-Proton

**In-Game Settings:**
- Graphics Preset: Medium
- Shadow Quality: Low-Medium
- Contact Shadows: Off
- Volumetric Fog: Low
- Motion Blur, Depth of Field, Vignette: Off
- Frame Cap: 40 FPS (Deck) or 60 FPS (Desktop)

---

### Last Epoch

**Best Preset:** `lastepoch` (normal) or `lastepoch-lowvram` (4-6GB VRAM)

**Steam Launch Options:**
```bash
# For 8GB+ VRAM:
gamelaunch --preset lastepoch %command%

# For 4-6GB VRAM (uses OpenGL instead of Vulkan):
gamelaunch --preset lastepoch-lowvram %command%
```

**Known Issues & Fixes:**
- **VRAM usage after patch 1.2**: Use DXVK config (see below)
- **Long-session stutters**: LD_PRELOAD="" helps (included in preset)
- **Recommended Proton**: Proton GE 9-27 or newer

**DXVK Configuration Recommended:**
```bash
cp ~/.config/dotfiles/gaming/dxvk-configs/lastepoch.conf \
   ~/.local/share/Steam/steamapps/common/"Last Epoch"/dxvk.conf
```

**In-Game Settings:**
- Lower shadows, ambient occlusion, volumetric lighting
- Reduce texture quality if you have low VRAM

---

## 📋 DXVK Configuration Files

Some games need custom DXVK configs to manage VRAM properly. Templates are stored in:
```
~/.config/dotfiles/gaming/dxvk-configs/
```

### Available Templates:
- `diablo4-nvidia.conf` - Diablo 4 for NVIDIA GPUs
- `diablo4-amd.conf` - Diablo 4 for AMD GPUs
- `lastepoch.conf` - Last Epoch VRAM optimization

### How to Apply:

**Manual copy (one-time):**
```bash
cp ~/.config/dotfiles/gaming/dxvk-configs/diablo4-nvidia.conf \
   ~/.local/share/Steam/steamapps/common/"Diablo IV"/dxvk.conf
```

**Symlink (auto-updates with dotfiles):**
```bash
ln -sf ~/.config/dotfiles/gaming/dxvk-configs/diablo4-nvidia.conf \
       ~/.local/share/Steam/steamapps/common/"Diablo IV"/dxvk.conf
```

### Adjusting for Your GPU:

Edit the config file and adjust `dxgi.maxDeviceMemory` based on your VRAM:
- 8GB card: `6144` (leave 2GB headroom)
- 12GB card: `10240`
- 16GB card: `14336`
- 24GB card: `20480`

---

## 🔍 Finding Game Directories

Steam games are typically at:
```
~/.local/share/Steam/steamapps/common/
```

To find a specific game:
```bash
ls ~/.local/share/Steam/steamapps/common/ | grep -i "diablo"
find ~/.local/share/Steam/steamapps/common/ -name "*.exe" | grep -i "epoch"
```

---

## 📊 Monitoring Performance

Use the `debug` preset to see full diagnostics:
```bash
gamelaunch --preset debug %command%
```

This enables:
- Full MangoHud stats
- Proton logging
- DXVK HUD

Logs are saved to: `~/.config/game-launcher/launch.log`

---

## 🆘 Troubleshooting

### Game won't start
1. Try `compatibility` preset: `gamelaunch --preset compatibility %command%`
2. Check Proton version (try GE-Proton or Proton Experimental)
3. Look at Proton logs with debug preset

### Low FPS
1. Try hardware-specific preset: `amd-optimized` or `nvidia-optimized`
2. Lower in-game settings
3. Check if correct GPU is being used (laptop users: try `laptop-dgpu` preset)

### Crashes after 30-60 minutes
1. Likely VRAM issue - apply appropriate DXVK config
2. Lower texture quality in-game
3. Try `lowvram` preset variant if available

### Multiplayer lag/desync
1. Use `competitive` preset (disables esync)
2. Check your actual network connection
3. Disable async shader compilation for multiplayer: remove `DXVK_ASYNC=1`

---

For more information, see:
- Main README: `~/.config/dotfiles/gaming/README.md`
- DXVK Configs: `~/.config/dotfiles/gaming/dxvk-configs/README.md`
- Quick Start: `~/.config/dotfiles/gaming/QUICKSTART.md`

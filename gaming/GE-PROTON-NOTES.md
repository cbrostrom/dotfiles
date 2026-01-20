# GE-Proton Optimization Notes

## What GE-Proton 10-28 Changes:

### Core Updates (January 2, 2026):
- **Latest DXVK** - Better Vulkan performance
- **Latest VKD3D-Proton** - Better DirectX 12 support
- **Updated DXVK-NVAPI** - Better NVIDIA GPU support
- **Wine-Wayland patches** - Better Wayland support
- **Spatial audio fixes** - Fixed Wine-ALSA issues

### Why This Matters for Diablo 4:

1. **DXVK Updates** - Better shader compilation and VRAM management
2. **VKD3D Updates** - Diablo 4 uses DirectX 12, so this is critical
3. **DXVK-NVAPI** - Your RTX 2070 Super benefits from better NVIDIA support

## Recommended Settings for GE-Proton 10-28:

### For Diablo 4:
```bash
gamelaunch --preset diablo4 %command%
```

This now includes:
- `VKD3D_CONFIG=dxr11` - Optimizes DirectX 12 raytracing support
- `DXVK_ASYNC=1` - Works better with latest DXVK
- `PROTON_ENABLE_NVAPI=1` - Fully supported in 10-28

### Additional Tweaks You Can Try:

**If you experience stuttering:**
```bash
# Add to Steam launch options:
VKD3D_SHADER_CACHE_PATH=/tmp/vkd3d_cache gamelaunch --preset diablo4 %command%
```

**If you want maximum stability:**
```bash
# Disable async (more stable but initial stutter)
gamelaunch --preset diablo4 %command%
# Then remove DXVK_ASYNC=1 from the preset temporarily
```

**If Battle.net launcher has issues:**
```bash
# Force DX11 for launcher only
PROTON_USE_D3D11=1 %command%
```

## Known Issues with GE-Proton 10-28:

- **None specific to Diablo 4** - No reported issues
- **Spatial audio** - Fixed in this version
- **Uplay overlay** - Re-enabled (not relevant for Battle.net)

## What to Check:

1. **Shader Cache Location**
   - Check: `~/.cache/mesa_shader_cache/`
   - Should grow over time (first ~30min will stutter as it builds)

2. **VKD3D Cache**
   - Check: `~/.local/share/Steam/steamapps/shadercache/2344520/`
   - Should contain compiled shaders

3. **DXVK State Cache**
   - Check: `~/.local/share/Steam/steamapps/compatdata/2344520/pfx/drive_c/users/steamuser/AppData/Local/DXVK_state_cache/`
   - Helps with shader compilation

## Debugging with GE-Proton:

The debug preset now includes `VKD3D_DEBUG=warn` implicitly through VKD3D_CONFIG.

Use:
```bash
gamelaunch --preset diablo4-debug %command%
```

Then check logs with:
```bash
diablo4-debug
```

## Performance Tips for GE-Proton:

1. **Let shaders compile** - First 15-30 minutes will stutter
2. **VRAM limit is key** - Your dxvk.conf (6144 MB) is correct for 8GB
3. **Monitor temps** - MangoHud will show if GPU is thermal throttling
4. **Check for driver updates** - NVIDIA 565+ drivers work best

## If Game Still Won't Start:

**Step 1: Clear shader cache**
```bash
rm -rf ~/.local/share/Steam/steamapps/shadercache/2344520/
rm -rf ~/.cache/mesa_shader_cache/
```

**Step 2: Rebuild Proton prefix**
```bash
rm -rf ~/.local/share/Steam/steamapps/compatdata/2344520/
# Restart game (will rebuild)
```

**Step 3: Try without DXVK_ASYNC temporarily**
Edit preset and remove `DXVK_ASYNC=1`, then:
```bash
gamelaunch --preset diablo4 %command%
```

**Step 4: Check Battle.net launcher**
Sometimes the launcher itself has issues. Try:
```bash
# Kill any hanging Battle.net processes
pkill -9 -i battle
pkill -9 -i agent

# Then start game fresh
```

## Comparing to Proton Experimental:

GE-Proton 10-28 is generally **better** than Proton Experimental for Diablo 4 because:
- More aggressive optimizations
- Faster DXVK/VKD3D updates
- Community-tested fixes

If GE-Proton still doesn't work, you can try:
- Proton 9.0-3 (more stable, older)
- Proton Experimental (latest vanilla)
- GE-Proton 10-27 (previous version)

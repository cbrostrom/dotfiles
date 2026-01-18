# Game Launcher - Quick Reference Guide

## Installation Complete! ✅

Your game launcher is installed and ready to use.

## Files Created:
- Script: ~/bin/game-launch
- Config: ~/.config/game-launcher/presets.conf
- Logs: ~/.config/game-launcher/launch.log

## How to Use in Steam:

### Method 1: Using Presets (Recommended)
Right-click game → Properties → Launch Options:
```
gamelaunch --preset diablo4 %command%
```

### Method 2: Manual Options
```
gamelaunch --gamemode --mangohud %command%
```

### Method 3: Custom Config
```
gamelaunch --gamemode --mangohud --mangohud-config "fps,fps_limit=60" %command%
```

## Available Presets:

- **default** - Gamemode + MangoHud with standard info
- **performance** - Max performance, minimal overlay
- **diablo4** - Optimized for Diablo 4 (DXVK_ASYNC enabled)
- **competitive** - Minimal distractions, no esync (stable multiplayer)
- **debug** - Full monitoring with Proton logging
- **capped60** - 60 FPS limit
- **capped120** - 120 FPS limit
- **minimal** - Only gamemode, no overlay
- **monitor** - Only MangoHud, no gamemode
- **streaming** - Optimized for OBS streaming
- **amd-optimized** - Best for AMD GPUs (DXVK_ASYNC + ACO shader compiler)
- **nvidia-optimized** - Best for NVIDIA GPUs (NVAPI enabled)
- **compatibility** - Use OpenGL instead of Vulkan for problematic games
- **laptop-dgpu** - Force dedicated GPU on hybrid laptop systems
- **32bit-fix** - Allow larger address space for 32-bit games

## Creating Custom Presets:

Edit: ~/.config/game-launcher/presets.conf

Example:
```
[my-game]
gamemode=true
mangohud=true
mangohud_config=fps,gpu_temp,cpu_temp,fps_limit=144
env=DXVK_ASYNC=1 RADV_PERFTEST=gpl
```

## MangoHud Common Options:

- fps - Show FPS
- gpu_temp - GPU temperature
- cpu_temp - CPU temperature
- ram - RAM usage
- vram - VRAM usage
- fps_limit=60 - Limit framerate to 60
- position=top-left - Position (top-left, top-right, bottom-left, bottom-right)
- font_size=24 - Font size
- fps_only - Show only FPS
- full - Show all available info

Full list: https://github.com/flightlessmango/MangoHud#mangohud_config-options

## Useful Environment Variables:

### Performance (Built into presets)
- `DXVK_ASYNC=1` - Async shader compilation (smoother performance)
- `RADV_PERFTEST=aco` - AMD ACO shader compiler (faster on AMD)
- `PROTON_ENABLE_NVAPI=1` - Enable NVIDIA-specific features
- `mesa_glthread=true` - OpenGL threaded optimization

### Compatibility Fixes
- `PROTON_USE_WINED3D=1` - Use OpenGL instead of Vulkan (older GPUs)
- `PROTON_NO_ESYNC=1` - Disable esync (multiplayer stability)
- `PROTON_NO_FSYNC=1` - Disable fsync (if esync causes issues)
- `PROTON_FORCE_LARGE_ADDRESS_AWARE=1` - Larger address space (32-bit games)

### Debugging
- `PROTON_LOG=1` - Enable Proton logging
- `DXVK_HUD=fps` - DXVK's built-in FPS counter
- `WINEDEBUG=-all` - Disable Wine debug output

### Multi-GPU
- `DRI_PRIME=1` - Force dedicated GPU on hybrid systems

**Note**: Most of these are already configured in the appropriate presets!

## Testing:

Run this to test (won't launch a game):
```
gamelaunch --preset default echo "Test successful!"
```

## Troubleshooting:

Check logs:
```
tail -f ~/.config/game-launcher/launch.log
```

Test if gamemode works:
```
gamemoderun echo "Gamemode test"
```

Test if mangohud works:
```
mangohud glxgears
```

## Examples for Popular Games:

### Diablo 4:
```
gamelaunch --preset diablo4 %command%
```

### Competitive FPS (CS2, Valorant, etc):
```
gamelaunch --preset competitive %command%
```

### Chill gaming with 60 FPS cap:
```
gamelaunch --preset capped60 %command%
```

### High refresh rate gaming:
```
gamelaunch --preset capped120 %command%
```

---

Need help? Run: gamelaunch --help

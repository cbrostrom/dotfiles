# Quick Fix for Diablo 4 Shader Pre-compile Crash

## Problem:
Shader pre-compilation crashes with exit code -10 trying to compile 146,369 shaders.
This kills the game before it even starts.

## Solution: Disable Shader Pre-Compilation in Steam

### Option 1: Via Steam Settings (Recommended)
1. Open Steam Settings
2. Go to: **Shader Pre-Caching** (under Downloads or Compatibility)
3. **DISABLE** "Enable Shader Pre-Caching"
4. OR: **DISABLE** "Allow background processing of Vulkan shaders"

### Option 2: Via Steam Launch Options
Add this to Steam Launch Options (before gamelaunch):
```
STEAM_DISABLE_SHADER_CACHE=1 gamelaunch --preset diablo4 %command%
```

### Option 3: Delete Shader Cache and Start Fresh
```bash
rm -rf ~/.local/share/Steam/steamapps/shadercache/2344520/
gamelaunch --preset diablo4 %command%
```

## Why This Happens:
- Diablo 4 has 146,369 Vulkan shaders
- fossilize_replay (Steam's shader compiler) can't handle it
- Gets killed (exit -10) = SIGTERM/SIGKILL
- Game never starts because shader pre-compile fails

## Best Approach:
1. Disable shader pre-cache in Steam Settings
2. Use: `gamelaunch --preset diablo4 %command%`
3. Let DXVK compile shaders at runtime (DXVK_ASYNC helps!)
4. First 10-15 minutes will have stutters, then smooth

## Alternative: Skip Only This Game
In Steam Library:
1. Right-click Diablo IV
2. Properties → Compatibility
3. Add to launch options: `STEAM_DISABLE_SHADER_CACHE=1 gamelaunch --preset diablo4 %command%`

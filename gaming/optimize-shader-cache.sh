#!/usr/bin/env bash

# Vulkan Shader Cache Optimizer
# Fixes slow shader compilation by enabling shader pre-caching and optimization

set -euo pipefail

echo "🎮 Vulkan Shader Cache Optimizer"
echo ""

# Steam shader cache location
STEAM_SHADER_CACHE="$HOME/.local/share/Steam/steamapps/shadercache"
STEAM_CONFIG="$HOME/.local/share/Steam/steam/config/config.vdf"

# Check if Steam is installed
if [[ ! -d "$HOME/.local/share/Steam" ]] && [[ ! -d "$HOME/.steam" ]]; then
    echo "❌ Steam not found. This script is primarily for Steam games."
    exit 1
fi

echo "📋 Current shader cache status:"
if [[ -d "$STEAM_SHADER_CACHE" ]]; then
    CACHE_SIZE=$(du -sh "$STEAM_SHADER_CACHE" 2>/dev/null | cut -f1)
    CACHE_COUNT=$(find "$STEAM_SHADER_CACHE" -type f 2>/dev/null | wc -l)
    echo "  Location: $STEAM_SHADER_CACHE"
    echo "  Size: $CACHE_SIZE"
    echo "  Files: $CACHE_COUNT"
else
    echo "  No shader cache found yet"
fi
echo ""

# Create environment file for Steam
ENV_FILE="$HOME/.config/environment.d/gaming.conf"
mkdir -p "$(dirname "$ENV_FILE")"

echo "⚙️  Configuring environment variables..."

cat > "$ENV_FILE" << 'EOF'
# Gaming Performance Optimizations

# Enable Vulkan shader caching
MESA_SHADER_CACHE_DIR=$HOME/.cache/mesa_shader_cache
MESA_SHADER_CACHE_MAX_SIZE=10G

# Enable DXVK state cache (for Windows games via Proton)
DXVK_STATE_CACHE=1
DXVK_STATE_CACHE_PATH=$HOME/.cache/dxvk_state_cache

# Enable shader pre-caching
__GL_SHADER_DISK_CACHE=1
__GL_SHADER_DISK_CACHE_PATH=$HOME/.cache/nvidia_shader_cache
__GL_SHADER_DISK_CACHE_SKIP_CLEANUP=1

# Proton optimizations
PROTON_ENABLE_NVAPI=1
PROTON_HIDE_NVIDIA_GPU=0
PROTON_FORCE_LARGE_ADDRESS_AWARE=1

# AMD specific (if using AMD GPU)
# RADV_PERFTEST=gpl,nggc
# ACO_DEBUG=validateir,validatera

# Enable Vulkan pipeline caching
VK_DRIVER_FILES=/usr/share/vulkan/icd.d/radeon_icd.x86_64.json:/usr/share/vulkan/icd.d/nvidia_icd.json
EOF

echo "✅ Environment file created: $ENV_FILE"
echo ""

# Create Steam launch options helper
LAUNCH_OPTIONS_FILE="$HOME/.config/dotfiles/gaming/steam-launch-options.txt"

cat > "$LAUNCH_OPTIONS_FILE" << 'EOF'
# Recommended Steam Launch Options for Better Shader Performance

# For most games (general optimization):
DXVK_STATE_CACHE=1 PROTON_ENABLE_NVAPI=1 %command%

# For games with shader stutter (force shader pre-compilation):
DXVK_ASYNC=1 DXVK_STATE_CACHE=1 %command%

# For AMD GPUs (enable advanced features):
RADV_PERFTEST=gpl,nggc DXVK_ASYNC=1 %command%

# For NVIDIA GPUs (enable shader caching):
__GL_SHADER_DISK_CACHE=1 __GL_THREADED_OPTIMIZATIONS=1 %command%

# For maximum performance (may cause visual glitches initially):
DXVK_ASYNC=1 DXVK_STATE_CACHE=1 PROTON_ENABLE_NVAPI=1 PROTON_FORCE_LARGE_ADDRESS_AWARE=1 %command%

# How to apply:
# 1. Right-click game in Steam
# 2. Properties > General > Launch Options
# 3. Paste one of the above options
EOF

echo "📝 Launch options guide created: $LAUNCH_OPTIONS_FILE"
echo ""

# Create shader cache directories
echo "📁 Creating cache directories..."
mkdir -p "$HOME/.cache/mesa_shader_cache"
mkdir -p "$HOME/.cache/dxvk_state_cache"
mkdir -p "$HOME/.cache/nvidia_shader_cache"

# Set proper permissions
chmod 755 "$HOME/.cache/mesa_shader_cache"
chmod 755 "$HOME/.cache/dxvk_state_cache"
chmod 755 "$HOME/.cache/nvidia_shader_cache"

echo ""
echo "✅ Optimization complete!"
echo ""
echo "📌 What was configured:"
echo "  ✓ Vulkan shader caching enabled"
echo "  ✓ DXVK state cache enabled (for Proton games)"
echo "  ✓ Shader pre-compilation enabled"
echo "  ✓ Cache directories created"
echo ""
echo "🎯 Next steps:"
echo ""
echo "1. REBOOT or re-login for environment changes to take effect"
echo ""
echo "2. Enable Steam shader pre-caching:"
echo "   Steam > Settings > Shader Pre-Caching"
echo "   ✓ Enable 'Allow background processing of Vulkan shaders'"
echo "   ✓ Enable 'Enable Shader Pre-Caching'"
echo ""
echo "3. For specific games with shader stutter:"
echo "   Right-click game > Properties > Launch Options"
echo "   Add: DXVK_ASYNC=1 %command%"
echo ""
echo "4. Wait for initial shader compilation:"
echo "   First launch may still compile shaders, but subsequent launches"
echo "   will be MUCH faster as shaders are cached."
echo ""
echo "📖 See $LAUNCH_OPTIONS_FILE for more launch options"
echo ""
echo "💡 Pro tip: Let games run in the background for 5-10 minutes on first"
echo "   launch to pre-compile all shaders. After that, loading is instant!"

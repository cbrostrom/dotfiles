#!/usr/bin/env bash

# Avatar: Frontiers of Pandora - Debug Launch Script
# Tests different configurations to find what works

set -euo pipefail

GAME_PATH="/mnt/games/fast/SteamLibrary/steamapps/common/AFOP/afop.exe"
COMPAT_DATA="/mnt/games/fast/SteamLibrary/steamapps/compatdata/2840770"
PROTON_PATH="$HOME/.local/share/Steam/compatibilitytools.d/GE-Proton10-28"

echo "🎮 Avatar: Frontiers of Pandora - Debug Launcher"
echo ""

# Check if game exists
if [[ ! -f "$GAME_PATH" ]]; then
    echo "❌ Game not found at: $GAME_PATH"
    exit 1
fi

echo "✅ Game found: $GAME_PATH"
echo "✅ Proton: $PROTON_PATH"
echo "✅ Compat data: $COMPAT_DATA"
echo ""

# Check GPU
GPU_INFO=$(lspci | grep -i vga || echo "Unknown GPU")
echo "🖥️  GPU: $GPU_INFO"
echo ""

# Check VRAM
if command -v nvidia-smi &> /dev/null; then
    VRAM=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits | head -1)
    echo "💾 VRAM: ${VRAM}MB"
    if [[ $VRAM -lt 8000 ]]; then
        echo "⚠️  WARNING: Avatar recommends 8GB+ VRAM"
    fi
elif command -v radeontop &> /dev/null; then
    echo "💾 AMD GPU detected"
else
    echo "💾 Could not detect VRAM"
fi
echo ""

# Menu
echo "Choose launch method:"
echo ""
echo "1. Standard (DXVK Async + VKD3D)"
echo "2. Safe Mode (No DXVK Async)"
echo "3. Compatibility (WINED3D)"
echo "4. Debug (Full logging)"
echo "5. Reset Proton Prefix (DELETE ALL SAVES!)"
echo "6. Check ProtonDB"
echo "7. Exit"
echo ""
read -p "Select option (1-7): " choice

case $choice in
    1)
        echo ""
        echo "🚀 Launching with DXVK Async..."
        echo "   This may have visual glitches for first 30 seconds"
        echo ""
        export STEAM_COMPAT_DATA_PATH="$COMPAT_DATA"
        export DXVK_ASYNC=1
        export VKD3D_CONFIG=dxr11
        export PROTON_ENABLE_NVAPI=1
        export PROTON_HIDE_NVIDIA_GPU=0
        export RADV_PERFTEST=gpl
        
        "$PROTON_PATH/proton" run "$GAME_PATH" -uplay_steam_mode -uplay_launcher
        ;;
    
    2)
        echo ""
        echo "🛡️  Launching in Safe Mode..."
        echo "   No DXVK Async - may take longer to start"
        echo ""
        export STEAM_COMPAT_DATA_PATH="$COMPAT_DATA"
        export VKD3D_CONFIG=dxr11
        export PROTON_ENABLE_NVAPI=1
        export PROTON_NO_ESYNC=1
        export PROTON_NO_FSYNC=1
        
        "$PROTON_PATH/proton" run "$GAME_PATH" -uplay_steam_mode -uplay_launcher
        ;;
    
    3)
        echo ""
        echo "🔧 Launching in Compatibility Mode..."
        echo "   Using WINED3D (slower but more compatible)"
        echo ""
        export STEAM_COMPAT_DATA_PATH="$COMPAT_DATA"
        export PROTON_USE_WINED3D=1
        export PROTON_NO_ESYNC=1
        export PROTON_NO_FSYNC=1
        
        "$PROTON_PATH/proton" run "$GAME_PATH" -uplay_steam_mode -uplay_launcher
        ;;
    
    4)
        echo ""
        echo "🐛 Launching with full debug logging..."
        echo "   Logs will be saved to: $COMPAT_DATA/proton_*.log"
        echo ""
        export STEAM_COMPAT_DATA_PATH="$COMPAT_DATA"
        export PROTON_LOG=1
        export DXVK_LOG_LEVEL=info
        export DXVK_HUD=devinfo,fps
        export WINEDEBUG=+timestamp,+tid,+seh
        export DXVK_ASYNC=1
        export VKD3D_CONFIG=dxr11
        export PROTON_ENABLE_NVAPI=1
        
        "$PROTON_PATH/proton" run "$GAME_PATH" -uplay_steam_mode -uplay_launcher
        
        echo ""
        echo "Game closed. Check logs:"
        echo "  tail -100 $COMPAT_DATA/proton_*.log"
        ;;
    
    5)
        echo ""
        echo "⚠️  WARNING: This will DELETE:"
        echo "   - All game saves"
        echo "   - All settings"
        echo "   - Ubisoft Connect login"
        echo "   - Shader cache"
        echo ""
        read -p "Are you SURE? Type 'yes' to confirm: " confirm
        if [[ "$confirm" == "yes" ]]; then
            echo "Deleting Proton prefix..."
            rm -rf "$COMPAT_DATA"
            echo "✅ Deleted. Game will create new prefix on next launch."
            echo ""
            echo "Next steps:"
            echo "  1. Launch game via Steam"
            echo "  2. Wait for shader compilation (10-30 min)"
            echo "  3. Log into Ubisoft Connect"
        else
            echo "Cancelled."
        fi
        ;;
    
    6)
        echo ""
        echo "📖 Opening ProtonDB for Avatar..."
        xdg-open "https://www.protondb.com/app/2840770" 2>/dev/null || \
        echo "Visit: https://www.protondb.com/app/2840770"
        ;;
    
    7)
        echo "Exiting..."
        exit 0
        ;;
    
    *)
        echo "Invalid option"
        exit 1
        ;;
esac

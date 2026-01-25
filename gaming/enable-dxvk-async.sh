#!/usr/bin/env bash

# Enable DXVK Async for ALL Steam games
# This eliminates shader compilation stutter completely

set -euo pipefail

echo "🚀 DXVK Async Enabler"
echo ""
echo "This will enable asynchronous shader compilation for ALL Steam games."
echo "This eliminates the 'Processing Vulkan Shaders' wait time!"
echo ""

# Check if Steam is running
if pgrep -x "steam" > /dev/null; then
    echo "⚠️  Steam is currently running."
    read -p "Close Steam and continue? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "Closing Steam..."
        killall steam 2>/dev/null || true
        sleep 2
    else
        echo "Please close Steam manually and run this script again."
        exit 1
    fi
fi

# Create Steam launch options script
STEAM_LAUNCH_SCRIPT="$HOME/.local/bin/steam-with-dxvk-async"

cat > "$STEAM_LAUNCH_SCRIPT" << 'EOF'
#!/usr/bin/env bash
# Steam launcher with DXVK Async enabled globally

export DXVK_ASYNC=1
export DXVK_STATE_CACHE=1
export DXVK_STATE_CACHE_PATH="$HOME/.cache/dxvk_state_cache"
export MESA_SHADER_CACHE_DIR="$HOME/.cache/mesa_shader_cache"
export MESA_SHADER_CACHE_MAX_SIZE=10G

exec /usr/bin/steam "$@"
EOF

chmod +x "$STEAM_LAUNCH_SCRIPT"

echo "✅ Created Steam launcher with DXVK Async: $STEAM_LAUNCH_SCRIPT"
echo ""

# Create desktop file override
DESKTOP_FILE="$HOME/.local/share/applications/steam-dxvk-async.desktop"

cat > "$DESKTOP_FILE" << EOF
[Desktop Entry]
Name=Steam (DXVK Async)
Comment=Application for managing and playing games on Steam (with shader optimization)
Exec=$STEAM_LAUNCH_SCRIPT %U
Icon=steam
Terminal=false
Type=Application
Categories=Network;FileTransfer;Game;
MimeType=x-scheme-handler/steam;x-scheme-handler/steamlink;
Actions=Store;Community;Library;Servers;Screenshots;News;Settings;BigPicture;Friends;

[Desktop Action Store]
Name=Store
Exec=$STEAM_LAUNCH_SCRIPT steam://store

[Desktop Action Community]
Name=Community
Exec=$STEAM_LAUNCH_SCRIPT steam://url/SteamIDControlPage

[Desktop Action Library]
Name=Library
Exec=$STEAM_LAUNCH_SCRIPT steam://open/games

[Desktop Action Servers]
Name=Servers
Exec=$STEAM_LAUNCH_SCRIPT steam://open/servers

[Desktop Action Screenshots]
Name=Screenshots
Exec=$STEAM_LAUNCH_SCRIPT steam://open/screenshots

[Desktop Action News]
Name=News
Exec=$STEAM_LAUNCH_SCRIPT steam://open/news

[Desktop Action Settings]
Name=Settings
Exec=$STEAM_LAUNCH_SCRIPT steam://open/settings

[Desktop Action BigPicture]
Name=Big Picture
Exec=$STEAM_LAUNCH_SCRIPT steam://open/bigpicture

[Desktop Action Friends]
Name=Friends
Exec=$STEAM_LAUNCH_SCRIPT steam://open/friends
EOF

update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true

echo "✅ Created optimized Steam launcher"
echo ""
echo "🎯 How to use:"
echo ""
echo "Option 1 (Recommended): Use the new launcher"
echo "  - Search for 'Steam (DXVK Async)' in GNOME"
echo "  - Pin it to favorites"
echo "  - Use this instead of regular Steam"
echo ""
echo "Option 2: Replace default Steam launcher"
read -p "  Replace default Steam launcher? (y/N) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    SYSTEM_STEAM_DESKTOP="/usr/share/applications/steam.desktop"
    USER_STEAM_DESKTOP="$HOME/.local/share/applications/steam.desktop"
    
    if [[ -f "$SYSTEM_STEAM_DESKTOP" ]]; then
        cp "$SYSTEM_STEAM_DESKTOP" "$USER_STEAM_DESKTOP"
        sed -i "s|Exec=/usr/bin/steam|Exec=$STEAM_LAUNCH_SCRIPT|g" "$USER_STEAM_DESKTOP"
        sed -i "s|Exec=steam|Exec=$STEAM_LAUNCH_SCRIPT|g" "$USER_STEAM_DESKTOP"
        update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true
        echo "  ✅ Default Steam launcher replaced"
    fi
fi

echo ""
echo "✅ Setup complete!"
echo ""
echo "🎮 What this does:"
echo "  • Enables DXVK Async (asynchronous shader compilation)"
echo "  • Shaders compile in background while you play"
echo "  • NO MORE waiting for 'Processing Vulkan Shaders'"
echo "  • May see brief visual glitches on first launch (normal)"
echo "  • Subsequent launches are instant!"
echo ""
echo "💡 Note: First time playing a game may have minor visual artifacts"
echo "   for a few seconds while shaders compile in background. This is"
echo "   normal and much better than waiting 10+ minutes!"

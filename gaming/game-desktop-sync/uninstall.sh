#!/usr/bin/env bash

# Game Desktop Sync - Uninstallation Script

set -euo pipefail

echo "🗑️  Uninstalling Game Desktop Sync..."
echo ""

# Stop and disable services
echo "⏹️  Stopping services..."
systemctl --user stop game-desktop-sync.timer 2>/dev/null || true
systemctl --user stop game-desktop-sync.path 2>/dev/null || true
systemctl --user disable game-desktop-sync.timer 2>/dev/null || true
systemctl --user disable game-desktop-sync.path 2>/dev/null || true

# Remove scripts
echo "📝 Removing scripts..."
rm -f "$HOME/.local/bin/game-desktop-sync.sh"
rm -f "$HOME/.local/bin/game-desktop-sync-ctl"

# Remove systemd units
echo "⚙️  Removing systemd units..."
rm -f "$HOME/.config/systemd/user/game-desktop-sync.service"
rm -f "$HOME/.config/systemd/user/game-desktop-sync.timer"
rm -f "$HOME/.config/systemd/user/game-desktop-sync.path"

# Reload systemd
echo "🔄 Reloading systemd..."
systemctl --user daemon-reload

# Ask about desktop files
echo ""
read -p "Remove all auto-generated game desktop files? (y/N) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "🗑️  Removing desktop files..."
    rm -rf "$HOME/.local/share/applications/games-auto"
    update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true
fi

# Ask about log file
read -p "Remove log file? (y/N) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "🗑️  Removing log file..."
    rm -f "$HOME/.local/share/game-desktop-sync.log"
fi

echo ""
echo "✅ Uninstallation complete!"

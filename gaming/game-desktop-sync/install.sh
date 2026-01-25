#!/usr/bin/env bash

# Game Desktop Sync - Installation Script
# Installs scripts and systemd units for automatic game desktop file management

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="$HOME/.local/bin"
SYSTEMD_DIR="$HOME/.config/systemd/user"
DESKTOP_DIR="$HOME/.local/share/applications/games-auto"

echo "🎮 Installing Game Desktop Sync..."
echo ""

# Create directories
echo "📁 Creating directories..."
mkdir -p "$BIN_DIR"
mkdir -p "$SYSTEMD_DIR"
mkdir -p "$DESKTOP_DIR"

# Install scripts
echo "📝 Installing scripts..."
cp "$SCRIPT_DIR/game-desktop-sync.sh" "$BIN_DIR/"
cp "$SCRIPT_DIR/game-desktop-sync-ctl" "$BIN_DIR/"
chmod +x "$BIN_DIR/game-desktop-sync.sh"
chmod +x "$BIN_DIR/game-desktop-sync-ctl"

# Install systemd units
echo "⚙️  Installing systemd units..."
cp "$SCRIPT_DIR/game-desktop-sync.service" "$SYSTEMD_DIR/"
cp "$SCRIPT_DIR/game-desktop-sync.timer" "$SYSTEMD_DIR/"
cp "$SCRIPT_DIR/game-desktop-sync.path" "$SYSTEMD_DIR/"

# Reload systemd
echo "🔄 Reloading systemd..."
systemctl --user daemon-reload

echo ""
echo "✅ Installation complete!"
echo ""
echo "Next steps:"
echo "  1. Enable and start: game-desktop-sync-ctl enable && game-desktop-sync-ctl start"
echo "  2. Run first sync:   game-desktop-sync-ctl run"
echo "  3. Check status:     game-desktop-sync-ctl status"
echo ""
echo "Your games will now appear in GNOME Search! 🎮"

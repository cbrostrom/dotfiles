#!/usr/bin/env bash
# =============================================================================
# GNOME dconf Settings Restore Script
# =============================================================================
# This script restores GNOME settings from dconf-settings.ini
# Run this after a fresh GNOME installation or system migration
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_FILE="$SCRIPT_DIR/dconf-settings.ini"
EXTENSIONS_FILE="$SCRIPT_DIR/extensions-enabled.txt"

echo "==================================="
echo "GNOME dconf Restore Script"
echo "==================================="
echo ""

# Check if dconf is available
if ! command -v dconf &> /dev/null; then
    echo "❌ Error: dconf is not installed"
    echo "   Install it with: sudo pacman -S dconf (Arch) or sudo apt install dconf-cli (Debian/Ubuntu)"
    exit 1
fi

# Check if backup file exists
if [ ! -f "$BACKUP_FILE" ]; then
    echo "❌ Error: Backup file not found: $BACKUP_FILE"
    echo "   Run ./dconf-backup.sh first to create a backup"
    exit 1
fi

# Check if running GNOME
if [ "$XDG_CURRENT_DESKTOP" != "GNOME" ]; then
    echo "⚠️  Warning: Not running GNOME desktop (detected: $XDG_CURRENT_DESKTOP)"
    read -p "Continue anyway? (y/n): " continue_restore
    if [ "$continue_restore" != "y" ]; then
        echo "Restore cancelled"
        exit 0
    fi
fi

echo "📦 Restoring GNOME settings from: $BACKUP_FILE"
echo ""
echo "⚠️  This will overwrite your current GNOME settings!"
read -p "Continue? (y/n): " confirm_restore

if [ "$confirm_restore" != "y" ]; then
    echo "Restore cancelled"
    exit 0
fi

echo ""
echo "🔄 Restoring settings..."

# Parse and restore settings by category
declare -A CATEGORIES=(
    ["org/gnome/desktop/interface"]="Desktop Interface"
    ["org/gnome/desktop/wm"]="Window Manager"
    ["org/gnome/shell"]="Shell"
    ["org/gnome/settings-daemon/plugins/media-keys"]="Media Keys"
    ["org/gnome/desktop/wm/keybindings"]="WM Keybindings"
    ["org/gnome/terminal"]="Terminal"
    ["org/gnome/mutter"]="Mutter"
    ["org/gnome/desktop/session"]="Session"
    ["org/gnome/desktop/privacy"]="Privacy"
    ["org/gnome/desktop/notifications"]="Notifications"
)

# Create temporary directory for category files
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

# Split backup file into category sections
current_path=""
current_file=""

while IFS= read -r line; do
    # Detect path comments
    if [[ $line =~ ^#[[:space:]]*(org/gnome/[^[:space:]]+) ]]; then
        current_path="${BASH_REMATCH[1]}"
        current_file="$TEMP_DIR/${current_path//\//_}.dconf"
        > "$current_file"  # Create/clear file
    elif [ -n "$current_file" ] && [[ ! $line =~ ^#.*$ ]] && [ -n "$line" ]; then
        echo "$line" >> "$current_file"
    fi
done < "$BACKUP_FILE"

# Restore each category
for path in "${!CATEGORIES[@]}"; do
    category="${CATEGORIES[$path]}"
    temp_file="$TEMP_DIR/${path//\//_}.dconf"
    
    if [ -f "$temp_file" ] && [ -s "$temp_file" ]; then
        echo "📋 Restoring: $category"
        dconf load "/$path/" < "$temp_file" 2>/dev/null || echo "   ⚠️  Warning: Could not restore $category"
    fi
done

# Restore custom keybindings
echo ""
echo "🔑 Restoring custom keybindings"
custom_kb_file="$TEMP_DIR/org_gnome_settings-daemon_plugins_media-keys_custom-keybindings.dconf"
if [ -f "$custom_kb_file" ] && [ -s "$custom_kb_file" ]; then
    dconf load "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/" < "$custom_kb_file" 2>/dev/null || echo "   ⚠️  Warning: Could not restore custom keybindings"
fi

# Restore extensions list (informational only)
if [ -f "$EXTENSIONS_FILE" ]; then
    echo ""
    echo "🧩 Previously enabled extensions:"
    cat "$EXTENSIONS_FILE"
    echo ""
    echo "💡 Note: Extensions must be installed separately"
    echo "   See extensions-list.txt for recommended extensions"
fi

echo ""
echo "✅ Restore completed!"
echo ""
echo "🔄 Restart GNOME Shell to apply changes:"
echo "   - Press Alt+F2, type 'r', press Enter (X11)"
echo "   - Log out and log back in (Wayland)"
echo ""

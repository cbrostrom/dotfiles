#!/usr/bin/env bash
# =============================================================================
# GNOME Tools Installation Script
# =============================================================================
# Installs GNOME-specific tools and utilities for CachyOS/Arch Linux
# =============================================================================

set -e

echo "========================================="
echo "GNOME Tools Installation"
echo "========================================="
echo ""

# Check if running on Arch-based system
if ! command -v pacman &> /dev/null; then
    echo "❌ Error: This script is designed for Arch-based systems (CachyOS, Arch, Manjaro)"
    echo "   For other distributions, install packages manually"
    exit 1
fi

# Check if running GNOME
if [ "$XDG_CURRENT_DESKTOP" != "GNOME" ]; then
    echo "⚠️  Warning: Not running GNOME desktop (detected: $XDG_CURRENT_DESKTOP)"
    read -p "Continue anyway? (y/n): " continue_install
    if [ "$continue_install" != "y" ]; then
        echo "Installation cancelled"
        exit 0
    fi
fi

echo "📦 Installing GNOME tools and utilities..."
echo ""

# Core GNOME tools
CORE_PACKAGES=(
    "gnome-tweaks"              # Advanced GNOME settings
    "gnome-shell-extensions"    # Extension support
    "dconf-editor"              # dconf GUI editor
    "gnome-browser-connector"   # Browser extension connector
)

# Optional but recommended
OPTIONAL_PACKAGES=(
    "gnome-themes-extra"        # Additional themes
    "papirus-icon-theme"        # Modern icon theme
    "ttf-dejavu"                # Better fonts
    "ttf-liberation"            # Liberation fonts
)

# Development tools
DEV_PACKAGES=(
    "gnome-shell-extension-installer"  # CLI extension installer (AUR)
)

echo "Installing core packages..."
for package in "${CORE_PACKAGES[@]}"; do
    if pacman -Qi "$package" &> /dev/null; then
        echo "  ✓ $package (already installed)"
    else
        echo "  → Installing $package..."
        sudo pacman -S --noconfirm "$package" || echo "  ⚠️  Failed to install $package"
    fi
done

echo ""
read -p "Install optional packages (themes, fonts)? (y/n): " install_optional
if [ "$install_optional" = "y" ]; then
    echo "Installing optional packages..."
    for package in "${OPTIONAL_PACKAGES[@]}"; do
        if pacman -Qi "$package" &> /dev/null; then
            echo "  ✓ $package (already installed)"
        else
            echo "  → Installing $package..."
            sudo pacman -S --noconfirm "$package" || echo "  ⚠️  Failed to install $package"
        fi
    done
fi

echo ""
echo "✅ Core GNOME tools installed!"
echo ""

# Offer to install extensions
echo "========================================="
echo "GNOME Extensions"
echo "========================================="
echo ""
echo "Recommended extensions are listed in: extensions-list.txt"
echo ""
echo "To install extensions:"
echo "  1. Visit https://extensions.gnome.org/"
echo "  2. Install the browser extension"
echo "  3. Browse and install extensions"
echo ""
read -p "Open extensions website in browser? (y/n): " open_browser
if [ "$open_browser" = "y" ]; then
    if command -v xdg-open &> /dev/null; then
        xdg-open "https://extensions.gnome.org/" &
        echo "✓ Browser opened"
    else
        echo "⚠️  Could not open browser automatically"
        echo "   Visit: https://extensions.gnome.org/"
    fi
fi

echo ""
echo "========================================="
echo "Configuration Backup"
echo "========================================="
echo ""
read -p "Backup current GNOME settings? (y/n): " backup_settings
if [ "$backup_settings" = "y" ]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    "$SCRIPT_DIR/dconf-backup.sh"
fi

echo ""
echo "✅ GNOME tools installation complete!"
echo ""
echo "📋 Next steps:"
echo "  1. Install recommended extensions from extensions-list.txt"
echo "  2. Configure GNOME Tweaks (run: gnome-tweaks)"
echo "  3. Customize keybindings in Settings → Keyboard"
echo "  4. Backup your settings with: ./dconf-backup.sh"
echo ""
echo "💡 Useful commands:"
echo "  gnome-tweaks              # Open GNOME Tweaks"
echo "  gnome-extensions list     # List installed extensions"
echo "  dconf-editor              # Edit dconf settings (GUI)"
echo ""

#!/usr/bin/env bash
# =============================================================================
# Linux-Specific Dotfiles Installation Script
# =============================================================================
# Installs Linux-specific configurations (Ghostty, GNOME, etc.)
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(dirname "$SCRIPT_DIR")"
CONFIG_DIR="$HOME/.config"

echo "========================================="
echo "Linux Dotfiles Installation"
echo "========================================="
echo ""

# Detect desktop environment
detect_desktop_env() {
    if [ -n "$XDG_CURRENT_DESKTOP" ]; then
        echo "$XDG_CURRENT_DESKTOP"
    elif [ -n "$DESKTOP_SESSION" ]; then
        echo "$DESKTOP_SESSION"
    else
        echo "unknown"
    fi
}

DESKTOP_ENV=$(detect_desktop_env)
echo "🖥️  Detected desktop environment: $DESKTOP_ENV"
echo ""

# =============================================================================
# Ghostty Terminal Configuration
# =============================================================================
echo "========================================="
echo "Ghostty Terminal"
echo "========================================="
echo ""

if command -v ghostty &> /dev/null; then
    echo "✓ Ghostty is installed"
    
    # Create Ghostty config directory if it doesn't exist
    mkdir -p "$CONFIG_DIR/ghostty"
    
    # Check if config already exists
    if [ -f "$CONFIG_DIR/ghostty/config" ]; then
        echo "⚠️  Ghostty config already exists"
        read -p "Backup and replace with dotfiles version? (y/n): " replace_ghostty
        if [ "$replace_ghostty" = "y" ]; then
            cp "$CONFIG_DIR/ghostty/config" "$CONFIG_DIR/ghostty/config.backup.$(date +%Y%m%d_%H%M%S)"
            echo "  → Backed up existing config"
            ln -sf "$SCRIPT_DIR/ghostty/config" "$CONFIG_DIR/ghostty/config"
            echo "  ✓ Symlinked Ghostty config"
        else
            echo "  → Keeping existing config"
        fi
    else
        ln -sf "$SCRIPT_DIR/ghostty/config" "$CONFIG_DIR/ghostty/config"
        echo "✓ Symlinked Ghostty config"
    fi
else
    echo "⚠️  Ghostty is not installed"
    echo "   Install from: https://ghostty.org/"
    echo "   Or: yay -S ghostty (AUR)"
    echo ""
    read -p "Skip Ghostty configuration? (y/n): " skip_ghostty
    if [ "$skip_ghostty" != "y" ]; then
        exit 1
    fi
fi

echo ""

# =============================================================================
# Paru AUR Helper Configuration
# =============================================================================
echo "========================================="
echo "Paru Configuration"
echo "========================================="
echo ""

if command -v paru &> /dev/null; then
    echo "✓ Paru is installed"
    
    # Create paru config directory if it doesn't exist
    mkdir -p "$CONFIG_DIR/paru"
    
    # Check if config already exists
    if [ -f "$CONFIG_DIR/paru/paru.conf" ]; then
        echo "⚠️  Paru config already exists"
        read -p "Backup and replace with dotfiles version? (y/n): " replace_paru
        if [ "$replace_paru" = "y" ]; then
            cp "$CONFIG_DIR/paru/paru.conf" "$CONFIG_DIR/paru/paru.conf.backup.$(date +%Y%m%d_%H%M%S)"
            echo "  → Backed up existing config"
            ln -sf "$SCRIPT_DIR/paru/paru.conf" "$CONFIG_DIR/paru/paru.conf"
            echo "  ✓ Symlinked Paru config"
        else
            echo "  → Keeping existing config"
        fi
    else
        ln -sf "$SCRIPT_DIR/paru/paru.conf" "$CONFIG_DIR/paru/paru.conf"
        echo "✓ Symlinked Paru config"
    fi
else
    echo "⚠️  Paru is not installed"
    echo "   Install with: sudo pacman -S paru"
    echo "   Or build from AUR"
    echo ""
    echo "→ Skipping Paru configuration"
fi

echo ""

# =============================================================================
# GNOME-Specific Configuration (Optional)
# =============================================================================
if [[ "$DESKTOP_ENV" == *"GNOME"* ]] || [[ "$DESKTOP_ENV" == *"gnome"* ]]; then
    echo "========================================="
    echo "GNOME Desktop Environment"
    echo "========================================="
    echo ""
    echo "GNOME detected! Would you like to install GNOME-specific tools and configurations?"
    echo ""
    echo "This includes:"
    echo "  - GNOME Tweaks"
    echo "  - dconf settings backup/restore scripts"
    echo "  - Extension recommendations"
    echo "  - GNOME Shell customization tools"
    echo ""
    read -p "Install GNOME tools? (y/n): " install_gnome
    
    if [ "$install_gnome" = "y" ]; then
        echo ""
        if [ -f "$SCRIPT_DIR/gnome/install-gnome-tools.sh" ]; then
            "$SCRIPT_DIR/gnome/install-gnome-tools.sh"
        else
            echo "❌ Error: GNOME installation script not found"
        fi
        
        # Update .local-config
        LOCAL_CONFIG="$DOTFILES_DIR/.local-config"
        if [ -f "$LOCAL_CONFIG" ]; then
            if grep -q "DESKTOP_ENV=" "$LOCAL_CONFIG"; then
                sed -i 's/DESKTOP_ENV=.*/DESKTOP_ENV="gnome"/' "$LOCAL_CONFIG"
            else
                echo 'DESKTOP_ENV="gnome"' >> "$LOCAL_CONFIG"
            fi
            
            if grep -q "INSTALLED_OPTIONALS=" "$LOCAL_CONFIG"; then
                # Add gnome-tools if not already present
                if ! grep -q "gnome-tools" "$LOCAL_CONFIG"; then
                    sed -i 's/INSTALLED_OPTIONALS="\(.*\)"/INSTALLED_OPTIONALS="\1,gnome-tools"/' "$LOCAL_CONFIG"
                fi
            else
                echo 'INSTALLED_OPTIONALS="gnome-tools,ghostty"' >> "$LOCAL_CONFIG"
            fi
            
            echo "✓ Updated .local-config with GNOME settings"
        fi
    else
        echo "→ Skipping GNOME-specific setup"
        
        # Still update .local-config with desktop env
        LOCAL_CONFIG="$DOTFILES_DIR/.local-config"
        if [ -f "$LOCAL_CONFIG" ]; then
            if grep -q "DESKTOP_ENV=" "$LOCAL_CONFIG"; then
                sed -i 's/DESKTOP_ENV=.*/DESKTOP_ENV="gnome"/' "$LOCAL_CONFIG"
            else
                echo 'DESKTOP_ENV="gnome"' >> "$LOCAL_CONFIG"
            fi
        fi
    fi
else
    echo "========================================="
    echo "Desktop Environment: $DESKTOP_ENV"
    echo "========================================="
    echo ""
    echo "GNOME-specific setup is only available for GNOME desktop environment."
    echo "Your current desktop: $DESKTOP_ENV"
    echo ""
    
    # Update .local-config with detected desktop env
    LOCAL_CONFIG="$DOTFILES_DIR/.local-config"
    if [ -f "$LOCAL_CONFIG" ]; then
        DESKTOP_ENV_LOWER=$(echo "$DESKTOP_ENV" | tr '[:upper:]' '[:lower:]')
        if grep -q "DESKTOP_ENV=" "$LOCAL_CONFIG"; then
            sed -i "s/DESKTOP_ENV=.*/DESKTOP_ENV=\"$DESKTOP_ENV_LOWER\"/" "$LOCAL_CONFIG"
        else
            echo "DESKTOP_ENV=\"$DESKTOP_ENV_LOWER\"" >> "$LOCAL_CONFIG"
        fi
        echo "✓ Updated .local-config with desktop environment: $DESKTOP_ENV_LOWER"
    fi
fi

echo ""

# =============================================================================
# Directory Structure Setup
# =============================================================================
echo "========================================="
echo "Directory Structure"
echo "========================================="
echo ""

echo "Creating standard directories..."
mkdir -p "$HOME/Projects"
mkdir -p "$HOME/Work"
mkdir -p "$HOME/bin"
mkdir -p "$HOME/.local/bin"
mkdir -p "$HOME/.cache"

echo "✓ Directories created"
echo ""

# =============================================================================
# Micro Editor Plugins
# =============================================================================
if command -v micro &> /dev/null; then
    echo "========================================="
    echo "Micro Editor Plugins"
    echo "========================================="
    echo ""
    
    echo "Installing useful micro plugins..."
    micro -plugin install filemanager 2>/dev/null || echo "  → filemanager already installed or failed"
    micro -plugin install manipulator 2>/dev/null || echo "  → manipulator already installed or failed"
    micro -plugin install bounce 2>/dev/null || echo "  → bounce already installed or failed"
    micro -plugin install quoter 2>/dev/null || echo "  → quoter already installed or failed"
    
    echo "✓ Micro plugins configured"
    echo ""
fi

echo ""
echo "========================================="
echo "✅ Linux Installation Complete!"
echo "========================================="
echo ""
echo "📋 Summary:"
echo "  - Desktop Environment: $DESKTOP_ENV"
if command -v ghostty &> /dev/null; then
    echo "  - Ghostty: ✓ Configured"
else
    echo "  - Ghostty: ⚠️  Not installed"
fi
if command -v paru &> /dev/null; then
    echo "  - Paru: ✓ Configured"
else
    echo "  - Paru: ⚠️  Not installed"
fi
if command -v micro &> /dev/null; then
    echo "  - Micro: ✓ Configured with plugins"
else
    echo "  - Micro: ⚠️  Not installed"
fi
echo "  - Directories: ✓ Created (~/Projects, ~/Work, ~/bin)"
echo ""
echo "💡 Next steps:"
echo "  1. Restart your terminal to apply changes"
if [[ "$DESKTOP_ENV" == *"GNOME"* ]]; then
    echo "  2. Configure GNOME with: gnome-tweaks"
    echo "  3. Backup GNOME settings: cd linux/gnome && ./dconf-backup.sh"
fi
echo ""

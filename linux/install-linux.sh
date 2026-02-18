#!/usr/bin/env bash
# =============================================================================
# Linux-Specific Dotfiles Installation Script
# =============================================================================
# Installs Linux-specific configurations (Ghostty, etc.)
# Skips Ghostty on WSL (uses Windows Terminal instead)
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(dirname "$SCRIPT_DIR")"
CONFIG_DIR="$HOME/.config"
IS_WSL=false
grep -q Microsoft /proc/version 2>/dev/null && IS_WSL=true

echo "========================================="
echo "Linux Dotfiles Installation"
echo "========================================="
echo ""

# =============================================================================
# Ghostty Terminal Configuration (skip on WSL - uses Windows Terminal)
# =============================================================================
if $IS_WSL; then
    echo "WSL detected - skipping Ghostty (use Windows Terminal)"
    echo ""
else
echo "========================================="
echo "Ghostty Terminal"
echo "========================================="
echo ""

if command -v ghostty &> /dev/null; then
    echo "✓ Ghostty is installed"
    
    # Create Ghostty config directory if it doesn't exist
    mkdir -p "$CONFIG_DIR/ghostty"
    
    # Check if config already exists and compare hashes
    if [ -f "$CONFIG_DIR/ghostty/config" ]; then
        # Calculate hashes
        EXISTING_HASH=$(sha256sum "$CONFIG_DIR/ghostty/config" 2>/dev/null | cut -d' ' -f1)
        DOTFILES_HASH=$(sha256sum "$SCRIPT_DIR/ghostty/config" 2>/dev/null | cut -d' ' -f1)
        
        if [ "$EXISTING_HASH" = "$DOTFILES_HASH" ]; then
            echo "✓ Ghostty config is up to date"
        else
            echo "⚠️  Ghostty config differs from dotfiles version"
            read -p "Backup and replace with dotfiles version? (y/n): " replace_ghostty
            if [ "$replace_ghostty" = "y" ]; then
                cp "$CONFIG_DIR/ghostty/config" "$CONFIG_DIR/ghostty/config.backup.$(date +%Y%m%d_%H%M%S)"
                echo "  → Backed up existing config"
                ln -sf "$SCRIPT_DIR/ghostty/config" "$CONFIG_DIR/ghostty/config"
                echo "  ✓ Symlinked Ghostty config"
            else
                echo "  → Keeping existing config"
            fi
        fi
    else
        ln -sf "$SCRIPT_DIR/ghostty/config" "$CONFIG_DIR/ghostty/config"
        echo "✓ Symlinked Ghostty config"
    fi
else
    echo "⚠️  Ghostty is not installed"
    echo "   Install from: https://ghostty.org/"
    echo ""
    read -p "Skip Ghostty configuration? (y/n): " skip_ghostty
    if [ "$skip_ghostty" != "y" ]; then
        exit 1
    fi
fi

echo ""
fi
# End of non-WSL Ghostty block

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
$IS_WSL && echo "  - WSL: Windows Terminal (Ghostty skipped)" || true
if ! $IS_WSL && command -v ghostty &> /dev/null; then
    echo "  - Ghostty: ✓ Configured"
elif ! $IS_WSL; then
    echo "  - Ghostty: ⚠️  Not installed"
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
echo ""

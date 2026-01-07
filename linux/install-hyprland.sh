#!/usr/bin/env bash

# =============================================================================
# HYPRLAND SETUP INSTALLER
# =============================================================================
# Installs and configures Hyprland, Waybar, and optional components
# Part of the modular dotfiles system
# =============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Logging functions
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(dirname "$SCRIPT_DIR")"

# Check if running on Linux
if [[ "$OSTYPE" != "linux-gnu"* ]] && [[ "$OSTYPE" != "linux"* ]]; then
    log_error "This script is only for Linux systems"
    exit 1
fi

# Detect package manager
if command -v pacman &>/dev/null; then
    PKG_MANAGER="pacman"
elif command -v apt &>/dev/null; then
    PKG_MANAGER="apt"
elif command -v dnf &>/dev/null; then
    PKG_MANAGER="dnf"
else
    log_error "No supported package manager found (pacman/apt/dnf)"
    exit 1
fi

log_info "Detected package manager: $PKG_MANAGER"

# =============================================================================
# PACKAGE INSTALLATION
# =============================================================================

install_hyprland_packages() {
    log_info "Installing Hyprland and dependencies..."
    
    case "$PKG_MANAGER" in
        pacman)
            sudo pacman -S --needed --noconfirm \
                hyprland \
                hyprpaper \
                waybar \
                polkit-kde-agent \
                kitty \
                dolphin \
                wlogout \
                pavucontrol \
                brightnessctl \
                playerctl \
                nm-connection-editor \
                otf-font-awesome \
                ttf-jetbrains-mono-nerd
            
            # Install vicinae from AUR
            if command -v yay &>/dev/null; then
                yay -S --needed --noconfirm vicinae
            else
                log_warning "yay not found. Install vicinae manually: yay -S vicinae"
            fi
            ;;
        apt)
            sudo apt update
            sudo apt install -y \
                hyprland \
                waybar \
                kitty \
                policykit-1-gnome \
                pavucontrol \
                brightnessctl \
                playerctl \
                network-manager-gnome \
                fonts-font-awesome \
                fonts-jetbrains-mono
            log_warning "Vicinae needs manual installation on Debian/Ubuntu from: https://github.com/oknozor/vicinae"
            ;;
        dnf)
            sudo dnf install -y \
                hyprland \
                waybar \
                kitty \
                polkit-gnome \
                pavucontrol \
                brightnessctl \
                playerctl \
                network-manager-applet \
                fontawesome-fonts \
                jetbrains-mono-fonts
            log_warning "Vicinae needs manual installation on Fedora from: https://github.com/oknozor/vicinae"
            ;;
    esac
    
    log_success "Hyprland packages installed"
}

install_interception() {
    log_info "Installing interception-tools for Caps Lock remapping..."
    
    case "$PKG_MANAGER" in
        pacman)
            if command -v yay &>/dev/null; then
                yay -S --needed --noconfirm interception-tools interception-dual-function-keys
            else
                log_warning "yay not found. Install manually: yay -S interception-tools interception-dual-function-keys"
                return 1
            fi
            ;;
        *)
            log_warning "Interception-tools installation not automated for $PKG_MANAGER"
            log_info "Install manually from: https://gitlab.com/interception/linux/tools"
            return 1
            ;;
    esac
    
    log_success "Interception-tools installed"
}

# =============================================================================
# CONFIGURATION SETUP
# =============================================================================

setup_hyprland_config() {
    log_info "Setting up Hyprland configuration..."
    
    mkdir -p ~/.config/hypr
    
    # Symlink Hyprland configs (force overwrite if exists)
    ln -sf "$SCRIPT_DIR/hyprland/hyprland.conf" ~/.config/hypr/hyprland.conf
    ln -sf "$SCRIPT_DIR/hyprland/hyprpaper.conf" ~/.config/hypr/hyprpaper.conf
    
    log_success "Hyprland configuration symlinked"
}

setup_waybar_config() {
    log_info "Setting up Waybar configuration..."
    
    # Remove existing waybar config if it exists
    if [[ -e ~/.config/waybar ]] && [[ ! -L ~/.config/waybar ]]; then
        log_warning "Removing existing waybar directory (not a symlink)"
        rm -rf ~/.config/waybar
    fi
    
    # Symlink entire waybar directory
    ln -sf "$SCRIPT_DIR/waybar" ~/.config/waybar
    
    log_success "Waybar configuration symlinked"
}

setup_interception_config() {
    log_info "Setting up interception (Caps Lock dual-function)..."
    
    # Copy configs to system locations (requires sudo)
    sudo mkdir -p /etc/interception/udevmon.d
    sudo cp "$SCRIPT_DIR/interception/dual-function-keys.yaml" /etc/interception/
    sudo cp "$SCRIPT_DIR/interception/udevmon.yaml" /etc/interception/udevmon.d/caps-to-esc-super.yaml
    
    # Enable and start service
    sudo systemctl enable --now udevmon
    
    log_success "Interception configured and enabled"
}

# =============================================================================
# LOCAL CONFIG UPDATE
# =============================================================================

update_local_config() {
    local component="$1"
    local config_file="$DOTFILES_DIR/.local-config"
    
    if [[ ! -f "$config_file" ]]; then
        # Create from example
        cp "$DOTFILES_DIR/.local-config.example" "$config_file"
    fi
    
    # Add component to INSTALLED_OPTIONALS if not already there
    if ! grep -q "$component" "$config_file"; then
        sed -i "s/INSTALLED_OPTIONALS=\"\(.*\)\"/INSTALLED_OPTIONALS=\"\1,$component\"/" "$config_file"
        log_info "Added $component to .local-config"
    fi
}

# =============================================================================
# MAIN INSTALLATION
# =============================================================================

main() {
    log_info "Hyprland Setup Installer"
    echo ""
    
    # Ask what to install
    read -p "Install Hyprland packages? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        install_hyprland_packages
        setup_hyprland_config
        setup_waybar_config
        update_local_config "hyprland"
        update_local_config "waybar"
    fi
    
    echo ""
    read -p "Install interception-tools (Caps Lock remapping)? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        if install_interception; then
            setup_interception_config
            update_local_config "interception"
        fi
    fi
    
    echo ""
    log_success "Hyprland setup complete!"
    log_info "To use Hyprland:"
    log_info "  1. Log out of your current session"
    log_info "  2. Select 'Hyprland' from your display manager"
    log_info "  3. Log in"
    echo ""
    log_info "Keybinds:"
    log_info "  SUPER+R / ALT+SPACE - Launcher (Vicinae)"
    log_info "  SUPER+B      - Browser (Edge)"
    log_info "  SUPER+E      - Code (Cursor)"
    log_info "  SUPER+Q      - Terminal (Kitty)"
    log_info "  SUPER+SHIFT+S - Slack"
    log_info "  SUPER+T      - Teams"
    log_info "  SUPER+G      - Steam"
    log_info "  CAPS LOCK    - Tap: Esc, Hold: Super key"
}

main "$@"

#!/usr/bin/env bash
# =============================================================================
# GNOME WORKSTATION SETUP - ONE COMMAND TO RULE THEM ALL
# =============================================================================
# Complete setup for work-from-home + gaming on GNOME
# Installs: Work apps, gaming tools, dotfiles, GNOME configs
# =============================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# =============================================================================
# HELPER FUNCTIONS
# =============================================================================

print_header() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

print_success() { echo -e "${GREEN}✓${NC} $1"; }
print_warning() { echo -e "${YELLOW}⚠${NC} $1"; }
print_error() { echo -e "${RED}✗${NC} $1"; }
print_info() { echo -e "${CYAN}ℹ${NC} $1"; }

check_command() { command -v "$1" &>/dev/null; }
check_package() { pacman -Q "$1" &>/dev/null; }

# =============================================================================
# PLATFORM CHECK
# =============================================================================

check_platform() {
    print_header "Platform Check"
    
    # Check if Arch-based
    if ! check_command pacman; then
        print_error "This script requires an Arch-based distribution (CachyOS, Arch, Manjaro)"
        exit 1
    fi
    
    # Check if GNOME
    if [[ "$XDG_CURRENT_DESKTOP" != *"GNOME"* ]]; then
        print_warning "Not running GNOME (detected: $XDG_CURRENT_DESKTOP)"
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 0
        fi
    fi
    
    print_success "Platform: Arch-based Linux"
    print_success "Desktop: $XDG_CURRENT_DESKTOP"
    
    # Check for paru
    if ! check_command paru; then
        print_error "paru AUR helper is required but not installed"
        print_info "Install with: sudo pacman -S paru"
        exit 1
    fi
    
    print_success "AUR helper: paru"
}

# =============================================================================
# WORK SUITE INSTALLATION
# =============================================================================

install_work_suite() {
    print_header "Work Suite Installation"
    
    print_info "Installing work-from-home applications..."
    echo ""
    
    # Define packages
    local official_packages=(
        "teams-for-linux"      # Microsoft Teams
        "spotify-launcher"     # Spotify
    )
    
    local aur_packages=(
        "slack-desktop"        # Slack
        "outlook-for-linux-bin" # Outlook
        "ghostty"              # Terminal
        "cursor-bin"           # Code editor
        "vivaldi"              # Browser
    )
    
    # Install official packages
    local to_install=()
    for pkg in "${official_packages[@]}"; do
        if check_package "$pkg"; then
            print_success "$pkg (already installed)"
        else
            to_install+=("$pkg")
        fi
    done
    
    if [ ${#to_install[@]} -gt 0 ]; then
        print_info "Installing ${#to_install[@]} official package(s)..."
        sudo pacman -S --needed --noconfirm "${to_install[@]}"
    fi
    
    # Install AUR packages
    to_install=()
    for pkg in "${aur_packages[@]}"; do
        if check_package "$pkg"; then
            print_success "$pkg (already installed)"
        else
            to_install+=("$pkg")
        fi
    done
    
    if [ ${#to_install[@]} -gt 0 ]; then
        print_info "Installing ${#to_install[@]} AUR package(s)..."
        paru -S --needed --noconfirm "${to_install[@]}"
    fi
    
    print_success "Work suite installed!"
}

# =============================================================================
# GAMING TOOLS INSTALLATION
# =============================================================================

install_gaming_tools() {
    print_header "Gaming Tools Installation"
    
    print_info "Installing gaming performance tools..."
    echo ""
    
    local gaming_packages=(
        "gamemode"             # CPU/GPU performance boost
        "lib32-gamemode"       # 32-bit gamemode
        "mangohud"             # Performance overlay
        "lib32-mangohud"       # 32-bit mangohud
        "gamescope"            # Gaming compositor with FSR
        "steam"                # Steam client
        "protonup-qt"          # Proton version manager
    )
    
    local to_install=()
    for pkg in "${gaming_packages[@]}"; do
        if check_package "$pkg"; then
            print_success "$pkg (already installed)"
        else
            to_install+=("$pkg")
        fi
    done
    
    if [ ${#to_install[@]} -gt 0 ]; then
        print_info "Installing ${#to_install[@]} gaming package(s)..."
        sudo pacman -S --needed --noconfirm "${to_install[@]}"
    fi
    
    # Add user to gamemode group
    if ! groups | grep -q gamemode; then
        print_info "Adding user to gamemode group..."
        sudo usermod -aG gamemode "$USER"
        print_warning "You need to log out and back in for gamemode group to take effect"
    else
        print_success "User already in gamemode group"
    fi
    
    print_success "Gaming tools installed!"
}

# =============================================================================
# GNOME TOOLS INSTALLATION
# =============================================================================

install_gnome_tools() {
    print_header "GNOME Tools Installation"
    
    print_info "Installing GNOME configuration tools..."
    echo ""
    
    local gnome_packages=(
        "gnome-tweaks"              # Advanced GNOME settings
        "gnome-shell-extensions"    # Extension support
        "dconf-editor"              # dconf GUI editor
        "gnome-browser-connector"   # Browser extension connector
        "gnome-themes-extra"        # Additional themes
        "papirus-icon-theme"        # Modern icon theme
    )
    
    local to_install=()
    for pkg in "${gnome_packages[@]}"; do
        if check_package "$pkg"; then
            print_success "$pkg (already installed)"
        else
            to_install+=("$pkg")
        fi
    done
    
    if [ ${#to_install[@]} -gt 0 ]; then
        print_info "Installing ${#to_install[@]} GNOME package(s)..."
        sudo pacman -S --needed --noconfirm "${to_install[@]}"
    fi
    
    print_success "GNOME tools installed!"
}

# =============================================================================
# DOTFILES INSTALLATION
# =============================================================================

install_dotfiles() {
    print_header "Dotfiles Installation"
    
    print_info "Running main dotfiles installer..."
    echo ""
    
    if [[ -f "$SCRIPT_DIR/install.sh" ]]; then
        # Run full dotfiles installation
        bash "$SCRIPT_DIR/install.sh" --full
    else
        print_error "install.sh not found in $SCRIPT_DIR"
        return 1
    fi
    
    print_success "Dotfiles installed!"
}

# =============================================================================
# GAMING CONFIG SETUP
# =============================================================================

setup_gaming_config() {
    print_header "Gaming Configuration"
    
    print_info "Setting up gaming launcher and configs..."
    echo ""
    
    # Create directories
    mkdir -p "$HOME/bin"
    mkdir -p "$HOME/.config/game-launcher"
    mkdir -p "$HOME/.config/MangoHud"
    
    # Link gamelaunch script
    if [[ -f "$SCRIPT_DIR/gaming/bin/gamelaunch" ]]; then
        ln -sf "$SCRIPT_DIR/gaming/bin/gamelaunch" "$HOME/bin/gamelaunch"
        chmod +x "$SCRIPT_DIR/gaming/bin/gamelaunch"
        print_success "gamelaunch script linked"
    fi
    
    # Link gamelaunch-gen script
    if [[ -f "$SCRIPT_DIR/gaming/bin/gamelaunch-gen" ]]; then
        ln -sf "$SCRIPT_DIR/gaming/bin/gamelaunch-gen" "$HOME/bin/gamelaunch-gen"
        chmod +x "$SCRIPT_DIR/gaming/bin/gamelaunch-gen"
        print_success "gamelaunch-gen script linked"
    fi
    
    # Link presets
    if [[ -f "$SCRIPT_DIR/gaming/config/presets.conf" ]]; then
        ln -sf "$SCRIPT_DIR/gaming/config/presets.conf" "$HOME/.config/game-launcher/presets.conf"
        print_success "Gaming presets linked"
    fi
    
    # Link MangoHud config
    if [[ -f "$SCRIPT_DIR/gaming/config/MangoHud.conf" ]]; then
        ln -sf "$SCRIPT_DIR/gaming/config/MangoHud.conf" "$HOME/.config/MangoHud/MangoHud.conf"
        print_success "MangoHud config linked"
    fi
    
    print_success "Gaming configuration complete!"
}

# =============================================================================
# GNOME SETTINGS RESTORE
# =============================================================================

restore_gnome_settings() {
    print_header "GNOME Settings"
    
    if [[ -f "$SCRIPT_DIR/linux/gnome/dconf-settings.ini" ]]; then
        echo ""
        read -p "Restore GNOME settings from backup? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            print_info "Restoring GNOME settings..."
            dconf load / < "$SCRIPT_DIR/linux/gnome/dconf-settings.ini"
            print_success "GNOME settings restored!"
        else
            print_info "Skipping GNOME settings restore"
        fi
    else
        print_info "No GNOME settings backup found"
    fi
}

# =============================================================================
# GNOME GAMING OPTIMIZATIONS
# =============================================================================

apply_gnome_gaming_optimizations() {
    print_header "GNOME Gaming Optimizations"
    
    print_info "Applying gaming-specific GNOME settings..."
    echo ""
    
    # Disable animations for better gaming performance
    gsettings set org.gnome.desktop.interface enable-animations false
    print_success "Disabled animations (better gaming performance)"
    
    # Set performance power profile
    if check_command powerprofilesctl; then
        powerprofilesctl set performance 2>/dev/null || true
        print_success "Set power profile to performance"
    fi
    
    # Disable automatic screen blank
    gsettings set org.gnome.desktop.session idle-delay 0
    print_success "Disabled automatic screen blank"
    
    # Enable VRR (Variable Refresh Rate) if supported
    gsettings set org.gnome.mutter experimental-features "['variable-refresh-rate']"
    print_success "Enabled Variable Refresh Rate (VRR)"
    
    print_info ""
    print_warning "Note: You can re-enable animations later with:"
    print_info "  gsettings set org.gnome.desktop.interface enable-animations true"
}

# =============================================================================
# COMPLETION MESSAGE
# =============================================================================

show_completion() {
    print_header "Setup Complete! 🎉"
    
    cat << 'EOF'
Your GNOME workstation is now ready for work and gaming!

📦 Installed:
  ✓ Work Suite (Teams, Slack, Outlook, Cursor, Vivaldi)
  ✓ Gaming Tools (gamemode, mangohud, gamescope, Steam)
  ✓ GNOME Tools (Tweaks, Extensions, dconf-editor)
  ✓ Dotfiles (zsh, starship, modern CLI tools)
  ✓ Gaming Configs (gamelaunch, presets, MangoHud)

🎮 Gaming Quick Start:
  1. Open Steam
  2. Right-click a game → Properties → Launch Options
  3. Add: gamelaunch --preset nvidia-1080p %command%
  4. Press F12 in-game to toggle MangoHud overlay

📚 Documentation:
  • Gaming guide: ~/.config/dotfiles/gaming/README.md
  • Steam launch options: ~/.config/dotfiles/gaming/STEAM-LAUNCH-OPTIONS.md
  • List presets: gamelaunch-gen --list

💼 Work Apps:
  • Teams: teams-for-linux
  • Slack: slack
  • Outlook: outlook-for-linux
  • Cursor: cursor
  • Vivaldi: vivaldi

⚙️  GNOME Configuration:
  • Tweaks: gnome-tweaks
  • Extensions: https://extensions.gnome.org/
  • Backup settings: cd linux/gnome && ./dconf-backup.sh

🔄 Next Steps:
  1. Log out and back in (for gamemode group)
  2. Restart your terminal (for new PATH)
  3. Install GNOME extensions from: https://extensions.gnome.org/
  4. Configure GNOME Tweaks to your liking
  5. Test gaming with: gamelaunch --preset nvidia-1080p %command%

📊 Performance Tips:
  • Use 1080p upscaling for demanding games (nvidia-1080p preset)
  • Native 1440p for lighter games (nvidia-native preset)
  • Toggle MangoHud with F12 to monitor FPS/temps
  • Check gamemode status: gamemoded -s

🎯 Gaming Performance (RTX 2070 SUPER):
  • AAA games @ 1080p upscaled: 60-90 FPS
  • AAA games @ 1440p native: 40-60 FPS
  • Competitive @ 1080p: 144+ FPS

EOF

    if ! groups | grep -q gamemode; then
        echo ""
        print_warning "IMPORTANT: Log out and back in for gamemode to work!"
    fi
    
    echo ""
    print_success "Happy working and gaming! 🚀"
    echo ""
}

# =============================================================================
# MAIN MENU
# =============================================================================

show_menu() {
    clear
    cat << 'EOF'
╔════════════════════════════════════════════════════════════════════╗
║         GNOME Workstation Setup - Work + Gaming                   ║
╚════════════════════════════════════════════════════════════════════╝

EOF
    
    echo "This script will install and configure:"
    echo ""
    echo "  📦 Work Suite:"
    echo "     • Teams, Slack, Outlook (work email)"
    echo "     • Ghostty (terminal), Cursor (code editor)"
    echo "     • Vivaldi (browser), Spotify"
    echo ""
    echo "  🎮 Gaming Tools:"
    echo "     • gamemode, mangohud, gamescope"
    echo "     • Steam, Proton GE manager"
    echo "     • Gaming launcher with presets"
    echo ""
    echo "  ⚙️  GNOME Tools:"
    echo "     • GNOME Tweaks, Extensions support"
    echo "     • dconf editor, themes"
    echo ""
    echo "  🔧 Dotfiles:"
    echo "     • zsh with zinit, starship prompt"
    echo "     • Modern CLI tools (eza, bat, fzf, ripgrep)"
    echo "     • Git configs, aliases"
    echo ""
    echo "Estimated time: 10-15 minutes"
    echo ""
    read -p "Continue with installation? (y/N): " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Installation cancelled"
        exit 0
    fi
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

main() {
    # Parse arguments
    local skip_menu=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --yes|-y)
                skip_menu=true
                shift
                ;;
            --help|-h)
                echo "Usage: $0 [OPTIONS]"
                echo ""
                echo "Options:"
                echo "  -y, --yes    Skip confirmation menu"
                echo "  -h, --help   Show this help"
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                exit 1
                ;;
        esac
    done
    
    # Show menu unless skipped
    if ! $skip_menu; then
        show_menu
    fi
    
    # Run installation steps
    check_platform
    install_work_suite
    install_gaming_tools
    install_gnome_tools
    install_dotfiles
    setup_gaming_config
    restore_gnome_settings
    
    # Ask about gaming optimizations
    echo ""
    read -p "Apply GNOME gaming optimizations (disable animations, VRR)? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        apply_gnome_gaming_optimizations
    fi
    
    # Show completion message
    show_completion
}

# Run main function
main "$@"

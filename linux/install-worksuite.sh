#!/usr/bin/env bash
# =============================================================================
# WORK SUITE INSTALLER
# =============================================================================
# Installs essential work applications for Linux (CachyOS/Arch-based systems)
#
# Applications included:
#   - Slack (communication)
#   - Microsoft Teams (communication)
#   - Microsoft Outlook (work email)
#   - Mailspring (private email)
#   - Spotify (music)
#   - Ghostty (terminal)
#   - Cursor (code editor)
#   - Vivaldi (browser)
#
# Usage:
#   ./install-worksuite.sh [--check-only]
#
# Options:
#   --check-only    Only check what's installed, don't install anything
# =============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# =============================================================================
# HELPER FUNCTIONS
# =============================================================================

print_header() {
    echo -e "\n${BLUE}===================================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}===================================================${NC}\n"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

check_command() {
    command -v "$1" &>/dev/null
}

check_package() {
    pacman -Q "$1" &>/dev/null
}

# =============================================================================
# PLATFORM DETECTION
# =============================================================================

detect_platform() {
    if [[ ! -f /etc/os-release ]]; then
        print_error "Cannot detect Linux distribution"
        return 1
    fi
    
    source /etc/os-release
    
    case "$ID" in
        cachyos|arch|endeavouros|manjaro)
            PLATFORM="arch"
            ;;
        ubuntu|debian|pop)
            PLATFORM="debian"
            ;;
        fedora|rhel|centos)
            PLATFORM="fedora"
            ;;
        *)
            PLATFORM="unknown"
            ;;
    esac
    
    echo "$PLATFORM"
}

# =============================================================================
# PACKAGE DEFINITIONS
# =============================================================================

# Define work suite packages
declare -A OFFICIAL_PACKAGES=(
    ["teams-for-linux"]="Microsoft Teams client"
    ["spotify-launcher"]="Spotify music streaming"
    ["betterbird-bin"]="Betterbird email client (private)"
)

declare -A AUR_PACKAGES=(
    ["slack-desktop"]="Slack communication"
    ["outlook-for-linux-bin"]="Microsoft Outlook email"
    ["ghostty"]="Modern terminal emulator"
    ["cursor-bin"]="AI-powered code editor"
    ["vivaldi"]="Vivaldi web browser"
    ["beeper-v4-bin"]="Beeper unified messaging"
)

# =============================================================================
# CHECK INSTALLATION STATUS
# =============================================================================

check_installation_status() {
    print_header "Work Suite Installation Status"
    
    local all_installed=true
    
    echo "Official Packages (pacman):"
    for package in "${!OFFICIAL_PACKAGES[@]}"; do
        if check_package "$package"; then
            print_success "$package - ${OFFICIAL_PACKAGES[$package]}"
        else
            print_warning "$package - ${OFFICIAL_PACKAGES[$package]} (NOT INSTALLED)"
            all_installed=false
        fi
    done
    
    echo ""
    echo "AUR Packages (paru):"
    for package in "${!AUR_PACKAGES[@]}"; do
        if check_package "$package"; then
            print_success "$package - ${AUR_PACKAGES[$package]}"
        else
            print_warning "$package - ${AUR_PACKAGES[$package]} (NOT INSTALLED)"
            all_installed=false
        fi
    done
    
    echo ""
    if $all_installed; then
        print_success "All work suite packages are installed!"
        return 0
    else
        print_warning "Some packages are missing"
        return 1
    fi
}

# =============================================================================
# INSTALL PACKAGES
# =============================================================================

install_official_packages() {
    print_header "Installing Official Packages"
    
    local packages_to_install=()
    
    for package in "${!OFFICIAL_PACKAGES[@]}"; do
        if ! check_package "$package"; then
            packages_to_install+=("$package")
            print_info "Will install: $package - ${OFFICIAL_PACKAGES[$package]}"
        fi
    done
    
    if [ ${#packages_to_install[@]} -eq 0 ]; then
        print_success "All official packages already installed"
        return 0
    fi
    
    echo ""
    print_info "Installing ${#packages_to_install[@]} package(s)..."
    sudo pacman -S --needed --noconfirm "${packages_to_install[@]}"
    
    print_success "Official packages installed successfully"
}

install_aur_packages() {
    print_header "Installing AUR Packages"
    
    # Check if paru is installed
    if ! check_command paru; then
        print_error "paru is not installed. Please install paru first."
        return 1
    fi
    
    local packages_to_install=()
    
    for package in "${!AUR_PACKAGES[@]}"; do
        if ! check_package "$package"; then
            packages_to_install+=("$package")
            print_info "Will install: $package - ${AUR_PACKAGES[$package]}"
        fi
    done
    
    if [ ${#packages_to_install[@]} -eq 0 ]; then
        print_success "All AUR packages already installed"
        return 0
    fi
    
    echo ""
    print_info "Installing ${#packages_to_install[@]} package(s)..."
    paru -S --needed --noconfirm "${packages_to_install[@]}"
    
    print_success "AUR packages installed successfully"
}

# =============================================================================
# MAIN INSTALLATION
# =============================================================================

install_worksuite() {
    print_header "Work Suite Installer"
    
    # Detect platform
    PLATFORM=$(detect_platform)
    print_info "Detected platform: $PLATFORM"
    
    if [[ "$PLATFORM" != "arch" ]]; then
        print_error "This script is currently only supported on Arch-based distributions (CachyOS, Arch, EndeavourOS, Manjaro)"
        print_info "Detected: $ID"
        exit 1
    fi
    
    # Check current status
    echo ""
    if check_installation_status; then
        print_info "Nothing to install, all packages are already present"
        exit 0
    fi
    
    # Install packages
    echo ""
    read -p "Do you want to install missing packages? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_warning "Installation cancelled"
        exit 0
    fi
    
    install_official_packages
    install_aur_packages
    
    # Final status check
    echo ""
    check_installation_status
    
    print_header "Installation Complete!"
    print_info "You can now use:"
    echo "  - Slack: slack"
    echo "  - Teams: teams-for-linux"
    echo "  - Outlook: outlook-for-linux (work)"
    echo "  - Mailspring: mailspring (private)"
    echo "  - Spotify: spotify-launcher"
    echo "  - Ghostty: ghostty"
    echo "  - Cursor: cursor"
    echo "  - Vivaldi: vivaldi"
}

# =============================================================================
# MAIN SCRIPT
# =============================================================================

main() {
    # Parse arguments
    CHECK_ONLY=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --check-only)
                CHECK_ONLY=true
                shift
                ;;
            -h|--help)
                echo "Usage: $0 [--check-only]"
                echo ""
                echo "Options:"
                echo "  --check-only    Only check what's installed, don't install anything"
                echo "  -h, --help      Show this help message"
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                exit 1
                ;;
        esac
    done
    
    if $CHECK_ONLY; then
        check_installation_status
    else
        install_worksuite
    fi
}

main "$@"

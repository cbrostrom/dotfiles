#!/usr/bin/env bash

# Dotfiles Manager with smenu
# Uses smenu for interactive menu selection

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Logging functions
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to show fzf menu
show_fzf_menu() {
    local menu_items=(
        "Full installation"
        "Install dotfiles only"
        "Install dependencies only"
        "Uninstall dotfiles"
        "Check status"
        "Update dotfiles"
        "Preview installation"
        "Show help"
        "Reload shell configuration"
        "Force update symlinks"
        "Install missing tools"
        "Exit"
    )
    
    # Create menu string
    local menu_string=""
    for item in "${menu_items[@]}"; do
        menu_string+="$item\n"
    done
    
    # Show menu with fzf - much better than smenu
    local selection=$(echo -e "$menu_string" | fzf --height 40% --reverse --border --prompt "Select option: ")
    
    # Handle empty selection (user pressed Ctrl+C or escaped)
    if [[ -z "$selection" ]]; then
        log_info "No selection made. Exiting..."
        exit 0
    fi
    
    # Handle selection
    case "$selection" in
        "Full installation")
            log_info "Running: Full installation"
            run_install
            ;;
        "Install dotfiles only")
            log_info "Running: Install dotfiles only"
            run_install "--skip-deps"
            ;;
        "Install dependencies only")
            log_info "Running: Install dependencies only"
            run_install "--skip-dotfiles"
            ;;
        "Uninstall dotfiles")
            log_info "Running: Uninstall dotfiles"
            run_uninstall
            ;;
        "Check status")
            log_info "Running: Check status"
            run_status
            ;;
        "Update dotfiles")
            log_info "Running: Update dotfiles"
            update_dotfiles
            ;;
        "Preview installation")
            log_info "Running: Preview installation"
            run_install "--dry-run"
            ;;
        "Show help")
            show_help
            ;;
        "Reload shell configuration")
            log_info "Running: Reload shell configuration"
            reload_shell_config
            ;;
        "Force update symlinks")
            log_info "Running: Force update symlinks"
            run_force_update_symlinks
            ;;
        "Install missing tools")
            log_info "Running: Install missing tools"
            run_install_missing_tools
            ;;
        "Exit")
            log_info "Exiting..."
            exit 0
            ;;
        *)
            log_error "Unknown selection: '$selection'"
            ;;
    esac
}

# Function to install fzf
install_fzf() {
    log_info "fzf not found. Installing it automatically..."
    
    detect_os
    
    if $IS_MACOS; then
        log_info "Installing fzf via Homebrew..."
        if command_exists brew; then
            brew install fzf
            log_success "fzf installed via Homebrew"
        else
            log_error "Homebrew not found. Please install Homebrew first:"
            log_info "  /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
            exit 1
        fi
    elif $IS_LINUX; then
        log_info "Installing fzf via package manager..."
        
        # Try different package managers
        if command_exists apt; then
            sudo apt update && sudo apt install -y fzf
            log_success "fzf installed via apt"
        elif command_exists yum; then
            sudo yum install -y fzf
            log_success "fzf installed via yum"
        elif command_exists dnf; then
            sudo dnf install -y fzf
            log_success "fzf installed via dnf"
        elif command_exists pacman; then
            sudo pacman -S fzf
            log_success "fzf installed via pacman"
        else
            log_error "No supported package manager found. Please install fzf manually:"
            log_info "  Debian/Ubuntu: sudo apt install fzf"
            log_info "  RHEL/CentOS: sudo yum install fzf"
            log_info "  Fedora: sudo dnf install fzf"
            log_info "  Arch: sudo pacman -S fzf"
            exit 1
        fi
    else
        log_error "Unsupported OS. Please install fzf manually:"
        log_info "  Debian/Ubuntu: sudo apt install fzf"
        log_info "  macOS: brew install fzf"
        exit 1
    fi
    
    # Wait a moment for installation to complete
    sleep 1
    
    # Verify installation
    if command_exists fzf; then
        log_success "✓ fzf installed successfully!"
    else
        log_error "fzf installation may have failed. Please install it manually:"
        log_info "  Debian/Ubuntu: sudo apt install fzf"
        log_info "  macOS: brew install fzf"
        exit 1
    fi
}

# Function to show whiptail menu (improved fallback)
show_whiptail_menu() {
    # Use shorter menu items to avoid text splitting in whiptail
    local menu_items=(
        "Full install"
        "Dotfiles only"
        "Deps only"
        "Uninstall"
        "Status"
        "Update"
        "Preview"
        "Help"
        "Reload config"
        "Force symlinks"
        "Install tools"
        "Exit"
    )
    
    # Create menu string for whiptail with shorter items
    local menu_string=""
    local counter=1
    for item in "${menu_items[@]}"; do
        menu_string+="$counter \"$item\" "
        ((counter++))
    done
    
    # Show menu with whiptail - use smaller width to prevent splitting
    local selection=$(whiptail --title "Dotfiles Manager" --menu "Select an option:" 20 50 12 $menu_string 3>&1 1>&2 2>&3)
    
    # Handle empty selection (user pressed Cancel or escaped)
    if [[ -z "$selection" ]]; then
        log_info "No selection made. Exiting..."
        exit 0
    fi
    
    # Convert selection number to menu item
    local selected_item="${menu_items[$((selection-1))]}"
    
    # Handle selection
    case "$selected_item" in
        "Full install")
            log_info "Running: Full installation"
            run_install
            ;;
        "Dotfiles only")
            log_info "Running: Install dotfiles only"
            run_install "--skip-deps"
            ;;
        "Deps only")
            log_info "Running: Install dependencies only"
            run_install "--skip-dotfiles"
            ;;
        "Uninstall")
            log_info "Running: Uninstall dotfiles"
            run_uninstall
            ;;
        "Status")
            log_info "Running: Check status"
            run_status
            ;;
        "Update")
            log_info "Running: Update dotfiles"
            update_dotfiles
            ;;
        "Preview")
            log_info "Running: Preview installation"
            run_install "--dry-run"
            ;;
        "Help")
            show_help
            ;;
        "Reload config")
            log_info "Running: Reload shell configuration"
            reload_shell_config
            ;;
        "Force symlinks")
            log_info "Running: Force update symlinks"
            run_force_update_symlinks
            ;;
        "Install tools")
            log_info "Running: Install missing tools"
            run_install_missing_tools
            ;;
        "Exit")
            log_info "Exiting..."
            exit 0
            ;;
        *)
            log_error "Unknown selection: '$selected_item'"
            ;;
    esac
}

# Function to run install script
run_install() {
    local args="$1"
    if [[ -f "$SCRIPT_DIR/install.sh" ]]; then
        log_info "Running: ./install.sh $args"
        cd "$SCRIPT_DIR"
        ./install.sh $args
    else
        log_error "install.sh not found in $SCRIPT_DIR"
    fi
}

# Function to run uninstall script
run_uninstall() {
    if [[ -f "$SCRIPT_DIR/uninstall.sh" ]]; then
        log_info "Running: ./uninstall.sh"
        cd "$SCRIPT_DIR"
        ./uninstall.sh
    else
        log_error "uninstall.sh not found in $SCRIPT_DIR"
    fi
}

# Function to run status script
run_status() {
    if [[ -f "$SCRIPT_DIR/status.sh" ]]; then
        log_info "Running: ./status.sh"
        cd "$SCRIPT_DIR"
        ./status.sh
    else
        log_error "status.sh not found in $SCRIPT_DIR"
    fi
}

# Function to run force update symlinks
run_force_update_symlinks() {
    if [[ -f "$SCRIPT_DIR/force-update-symlinks.sh" ]]; then
        log_info "Running: ./force-update-symlinks.sh"
        cd "$SCRIPT_DIR"
        ./force-update-symlinks.sh
    else
        log_error "force-update-symlinks.sh not found in $SCRIPT_DIR"
    fi
}

# Function to run install missing tools
run_install_missing_tools() {
    if [[ -f "$SCRIPT_DIR/install-missing.sh" ]]; then
        log_info "Running: ./install-missing.sh"
        cd "$SCRIPT_DIR"
        ./install-missing.sh
    else
        log_error "install-missing.sh not found in $SCRIPT_DIR"
    fi
}

# Function to update dotfiles
update_dotfiles() {
    log_info "Updating dotfiles from git..."
    cd "$SCRIPT_DIR"
    
    if git status --porcelain | grep -q .; then
        log_warning "You have uncommitted changes. Please commit or stash them first."
        return 1
    fi
    
    if git pull origin main; then
        log_success "Dotfiles updated successfully!"
        log_info "Run './install.sh --verify' to ensure everything is up to date"
    else
        log_error "Failed to update dotfiles"
        return 1
    fi
}

# Function to check if shell config was modified
check_shell_config_modified() {
    # Check if .zshrc was modified recently (within last 5 minutes)
    if [[ -f "$HOME/.zshrc" ]]; then
        # Use different stat command based on OS
        local file_age
        if [[ "$OSTYPE" == "darwin"* ]]; then
            # macOS
            file_age=$(( $(date +%s) - $(stat -f %m "$HOME/.zshrc" 2>/dev/null || echo 0) ))
        else
            # Linux
            file_age=$(( $(date +%s) - $(stat -c %Y "$HOME/.zshrc" 2>/dev/null || echo 0) ))
        fi
        
        if [[ $file_age -lt 300 ]]; then  # 5 minutes = 300 seconds
            return 0  # Modified recently
        fi
    fi
    return 1  # Not modified recently
}

# Function to reload shell configuration
reload_shell_config() {
    # Only reload if shell config was actually modified
    if ! check_shell_config_modified; then
        log_info "No shell configuration changes detected."
        return 0
    fi
    
    log_info "Reloading shell configuration..."
    
    # Check if we're in an interactive shell
    if [[ -t 0 ]]; then
        # We're in an interactive shell, suggest reload
        echo
        log_success "✅ Shell configuration updated!"
        log_info "Your dotfiles have been configured successfully."
        log_info "To apply all changes, you can:"
        log_info "  1. Run: source ~/.zshrc"
        log_info "  2. Or restart your terminal session"
        log_info "  3. Or let us reload it for you now"
        echo
        
        # Ask if user wants to reload now
        read -p "🔄 Reload shell configuration now? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            log_info "🔄 Reloading shell configuration..."
            log_info "You should see your new prompt and tools available!"
            exec zsh
        else
            log_info "💡 Remember to run 'source ~/.zshrc' when ready!"
        fi
    else
        # Non-interactive shell, just inform
        log_success "✅ Shell configuration updated!"
        log_info "Run 'source ~/.zshrc' to apply changes."
        log_info "Or restart your terminal session."
    fi
}

# Function to show help
show_help() {
    cat <<'EOF'
Dotfiles Manager

This script provides an interactive menu for managing your dotfiles using fzf (with whiptail fallback).

Available options:
1. Full installation - Install everything with verification
2. Install dotfiles only - Only install dotfiles (skip dependencies)
3. Install dependencies only - Only install dependencies (skip dotfiles)
4. Uninstall dotfiles - Remove all dotfiles and configurations
5. Check status - Show status of all components
6. Update dotfiles - Pull latest changes from git
7. Preview installation - Show what would be installed (dry run)
8. Show help - Show this help message
9. Reload shell configuration - Reload zsh configuration
10. Force update symlinks - Force recreation of all symlinks
11. Install missing tools - Install only missing tools
12. Exit - Exit the menu

Usage:
  ./dotfiles.sh

Requirements:
  - fzf (preferred) or whiptail (fallback)
  - All dotfiles scripts in the same directory

Features:
  - Fuzzy search with fzf
  - Fallback to whiptail if fzf not available
  - Full text menu items (no splitting issues)

EOF
}

# Function to show system info
show_system_info() {
    echo -e "${CYAN}=== Dotfiles Manager ===${NC}"
    echo -e "${YELLOW}Script directory:${NC} $SCRIPT_DIR"
    echo -e "${YELLOW}Current shell:${NC} $SHELL"
    echo -e "${YELLOW}OS:${NC} $(uname -s) $(uname -r)"
    echo
}

# Function to detect OS
detect_os() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        OS_NAME="macOS"
        IS_MACOS=true
        IS_LINUX=false
    elif [[ "$OSTYPE" == "linux-gnu"* ]] || [[ "$OSTYPE" == "linux"* ]]; then
        OS_NAME="Linux"
        IS_MACOS=false
        IS_LINUX=true
        # Check for WSL
        if grep -q Microsoft /proc/version 2>/dev/null; then
            OS_NAME="WSL2"
        fi
    else
        OS_NAME="Unknown"
        IS_MACOS=false
        IS_LINUX=false
    fi
}



# Main function
main() {
    # Show system info
    show_system_info
    
    # Check if fzf is available, offer to install if not
    if ! command_exists fzf; then
        log_warning "fzf is not installed."
        echo
        log_info "Would you like to install fzf automatically? (y/N)"
        read -p "Press 'y' to auto-install, or any other key to continue with fallback: " -n 1 -r
        echo
        
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            install_fzf
        fi
    fi
    
    # Try fzf first (preferred), then whiptail as fallback
    if command_exists fzf; then
        log_info "Using fzf for menu selection"
        show_fzf_menu
    elif command_exists whiptail; then
        log_info "Using whiptail for menu selection (fzf not available)"
        show_whiptail_menu
    else
        log_error "Neither fzf nor whiptail is available. Please install one:"
        log_info "  Debian/Ubuntu: sudo apt install fzf"
        log_info "  macOS: brew install fzf"
        log_info "  Or whiptail is usually pre-installed on most systems"
        exit 1
    fi
}

# Run main function
main "$@"

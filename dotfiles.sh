#!/usr/bin/env bash

# Dotfiles Manager v1.0
# Modern menu interface for dotfiles installation and management
# Cross-platform compatible: macOS, Linux, WSL2

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

# Get script directory (cross-platform)
if [[ -n "$BASH_SOURCE" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
else
    SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
fi

# OS Detection
if [[ "$OSTYPE" == "darwin"* ]]; then
    IS_MACOS=true
    IS_LINUX=false
    OS_NAME="macOS"
elif [[ "$OSTYPE" == "linux-gnu"* ]] || [[ "$OSTYPE" == "linux"* ]]; then
    IS_MACOS=false
    IS_LINUX=true
    OS_NAME="Linux"
    # Check for WSL
    if grep -q Microsoft /proc/version 2>/dev/null; then
        IS_WSL=true
        OS_NAME="WSL2"
    else
        IS_WSL=false
    fi
else
    IS_MACOS=false
    IS_LINUX=false
    IS_WSL=false
    OS_NAME="Unknown"
fi

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to run install script
run_install() {
    local args="$1"
    if [[ -x "$SCRIPT_DIR/install.sh" ]]; then
        log_info "Running installer..."
        "$SCRIPT_DIR/install.sh" $args
    else
        log_error "install.sh not found or not executable"
        return 1
    fi
}

# Function to run uninstall script
run_uninstall() {
    local args="$1"
    if [[ -x "$SCRIPT_DIR/uninstall.sh" ]]; then
        log_info "Running uninstaller..."
        "$SCRIPT_DIR/uninstall.sh" $args
    else
        log_error "uninstall.sh not found or not executable"
        return 1
    fi
}

# Function to run status script
run_status() {
    if [[ -x "$SCRIPT_DIR/status.sh" ]]; then
        log_info "Checking status..."
        "$SCRIPT_DIR/status.sh"
    else
        log_error "status.sh not found or not executable"
        return 1
    fi
}

# Function to update dotfiles
update_dotfiles() {
    log_info "=== Updating Dotfiles ==="
    
    # Check if we're in a git repository
    if [[ ! -d "$SCRIPT_DIR/.git" ]]; then
        log_error "Not in a git repository. Cannot update."
        return 1
    fi
    
    # Fetch latest changes
    log_info "Fetching latest changes..."
    cd "$SCRIPT_DIR"
    git fetch origin
    
    # Check if there are updates
    local current_branch=$(git branch --show-current)
    local behind_count=$(git rev-list --count HEAD..origin/$current_branch 2>/dev/null || echo "0")
    
    if [[ "$behind_count" == "0" ]]; then
        log_success "Already up to date!"
        return 0
    fi
    
    log_info "Found $behind_count new commits. Updating..."
    
    # Pull latest changes
    git pull origin $current_branch
    
    # Reinstall dotfiles
    log_info "Reinstalling dotfiles..."
    run_install "--skip-deps"
    
    log_success "Update complete!"
    log_info "Please restart your terminal or run: source ~/.zshrc"
}

# Function to show help
show_help() {
    echo "Dotfiles Manager v1.0"
    echo
    echo "Usage: dotfiles [COMMAND] [OPTIONS]"
    echo
    echo "Commands:"
    echo "  install     - Install dotfiles and dependencies"
    echo "  uninstall   - Remove dotfiles and restore backups"
    echo "  status      - Show status of all components"
    echo "  update      - Update dotfiles from git and reinstall"
    echo "  dry-run     - Preview installation without making changes"
    echo "  reload      - Reload shell configuration"
    echo "  menu        - Show interactive menu (default)"
    echo "  help        - Show this help message"
    echo
    echo "Options:"
    echo "  --skip-deps     - Only install dotfiles (skip dependencies)"
    echo "  --skip-dotfiles - Only install dependencies (skip dotfiles)"
    echo "  --keep-backups  - Keep backup files during uninstall"
    echo
    echo "Examples:"
    echo "  dotfiles                    # Show interactive menu"
    echo "  dotfiles install            # Full installation"
    echo "  dotfiles install --skip-deps # Only install dotfiles"
    echo "  dotfiles uninstall          # Remove dotfiles"
    echo "  dotfiles status             # Check status"
    echo "  dotfiles update             # Update from git"
    echo "  dotfiles reload             # Reload shell configuration"
    echo "  dotfiles dry-run            # Preview installation"
    echo
    echo "This script provides a modern interface to the dotfiles v1.0 installation system."
    echo "All operations are cross-platform compatible (macOS, Linux, WSL2)."
}

# Function to show interactive menu
show_menu() {
    # Cross-platform clear command
    if command -v clear >/dev/null 2>&1; then
        clear 2>/dev/null || printf '\033[2J\033[H'
    else
        printf '\033[2J\033[H'
    fi

    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                    DOTFILES MANAGER v1.0                     ║${NC}"
    echo -e "${CYAN}╠══════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║  ${GREEN}1${NC} │ Install dotfiles (full installation)                ║${NC}"
    echo -e "${CYAN}║  ${GREEN}2${NC} │ Install dotfiles only (skip dependencies)          ║${NC}"
    echo -e "${CYAN}║  ${GREEN}3${NC} │ Install dependencies only (skip dotfiles)          ║${NC}"
    echo -e "${CYAN}║  ${GREEN}4${NC} │ Uninstall dotfiles (remove symlinks)               ║${NC}"
    echo -e "${CYAN}║  ${GREEN}5${NC} │ Check status of all components                     ║${NC}"
    echo -e "${CYAN}║  ${GREEN}6${NC} │ Update dotfiles (git pull + reinstall)             ║${NC}"
    echo -e "${CYAN}║  ${GREEN}7${NC} │ Preview installation (dry-run)                     ║${NC}"
    echo -e "${CYAN}║  ${GREEN}8${NC} │ Show help                                           ║${NC}"
    echo -e "${CYAN}║  ${BLUE}9${NC} │ Reload shell configuration                          ║${NC}"
    echo -e "${CYAN}║  ${RED}0${NC} │ Exit                                                 ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo
    echo -e "${YELLOW}Current OS:${NC} $OS_NAME ($(uname -s) $(uname -r))"
    echo -e "${YELLOW}Script directory:${NC} $SCRIPT_DIR"
    echo -e "${YELLOW}Current shell:${NC} $SHELL"
    echo
}

# Function to check if shell config was modified
check_shell_config_modified() {
    # Check if .zshrc was modified recently (within last 5 minutes)
    if [[ -f "$HOME/.zshrc" ]]; then
        local file_age=$(( $(date +%s) - $(stat -f %m "$HOME/.zshrc" 2>/dev/null || echo 0) ))
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

# Function to handle menu selection
handle_menu_selection() {
    local choice="$1"

    case "$choice" in
        1)
            log_info "Running: Full installation"
            run_install
            ;;
        2)
            log_info "Running: Install dotfiles only"
            run_install "--skip-deps"
            ;;
        3)
            log_info "Running: Install dependencies only"
            run_install "--skip-dotfiles"
            ;;
        4)
            log_info "Running: Uninstall dotfiles"
            run_uninstall
            ;;
        5)
            log_info "Running: Check status"
            run_status
            ;;
        6)
            log_info "Running: Update dotfiles"
            update_dotfiles
            ;;
        7)
            log_info "Running: Preview installation"
            run_install "--dry-run"
            ;;
        8)
            show_help
            ;;
        9)
            log_info "Running: Reload shell configuration"
            reload_shell_config
            ;;
        0)
            log_info "Exiting..."
            reload_shell_config
            exit 0
            ;;
        *)
            log_error "Invalid choice: $choice"
            return 1
            ;;
    esac
}

# Function to run interactive menu
run_menu() {
    while true; do
        show_menu
        read -p "Select option (0-9): " choice
        echo
        
        if handle_menu_selection "$choice"; then
            echo
            read -p "Press Enter to continue..."
        fi
    done
}

# Function to check git status
check_git_status() {
    if [[ -d "$SCRIPT_DIR/.git" ]]; then
        cd "$SCRIPT_DIR"
        local current_branch=$(git branch --show-current)
        local behind_count=$(git rev-list --count HEAD..origin/$current_branch 2>/dev/null || echo "0")
        
        if [[ "$behind_count" != "0" ]]; then
            log_warning "⚠ Updates available: $behind_count commits behind origin/$current_branch"
            log_info "Run 'dotfiles update' to update"
        fi
    fi
}

# Main script logic
main() {
    local command="${1:-menu}"
    local args="${@:2}"
    
    # Check for updates if running menu
    if [[ "$command" == "menu" ]]; then
        check_git_status
    fi
    
    case "$command" in
        install)
            run_install "$args"
            # Reload shell config after installation
            if [[ $? -eq 0 ]]; then
                reload_shell_config
            fi
            ;;
        uninstall)
            run_uninstall "$args"
            # Reload shell config after uninstallation
            if [[ $? -eq 0 ]]; then
                reload_shell_config
            fi
            ;;
        status)
            run_status
            ;;
        update)
            update_dotfiles
            # Reload shell config after update
            if [[ $? -eq 0 ]]; then
                reload_shell_config
            fi
            ;;
        "dry-run")
            run_install "--dry-run"
            ;;
        reload)
            reload_shell_config
            ;;
        menu)
            run_menu
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            log_error "Unknown command: $command"
            show_help
            exit 1
            ;;
    esac
}

# Run main function
main "$@"

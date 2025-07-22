#!/usr/bin/env bash

# Simple Dotfiles Symlink Handler
# Manages symlinks for dotfiles from the repository
# Cross-platform compatible: macOS, Linux, WSL2

set -e

# Terminal compatibility fix
if [[ -n "$TERM" ]]; then
    # Check if terminal type is supported
    if ! infocmp "$TERM" >/dev/null 2>&1; then
        # Fallback to common terminal types
        if infocmp "xterm-256color" >/dev/null 2>&1; then
            export TERM="xterm-256color"
        elif infocmp "xterm" >/dev/null 2>&1; then
            export TERM="xterm"
        elif infocmp "linux" >/dev/null 2>&1; then
            export TERM="linux"
        fi
    fi
fi

# OS Detection
if [[ "$OSTYPE" == "darwin"* ]]; then
    IS_MACOS=true
    IS_LINUX=false
elif [[ "$OSTYPE" == "linux-gnu"* ]] || [[ "$OSTYPE" == "linux"* ]]; then
    IS_MACOS=false
    IS_LINUX=true
    # Check for WSL
    if grep -q Microsoft /proc/version 2>/dev/null; then
        IS_WSL=true
    else
        IS_WSL=false
    fi
else
    IS_MACOS=false
    IS_LINUX=false
    IS_WSL=false
fi

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

# Get script directory (works with both bash and zsh)
if [[ -n "$BASH_SOURCE" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
else
    SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
fi

# Function to create symlink
create_symlink() {
    local source="$1"
    local target="$2"
    local description="$3"

    if [[ ! -f "$source" ]]; then
        log_error "Source file not found: $source"
        return 1
    fi

    # Check if target already exists
    if [[ -L "$target" ]]; then
        log_info "Removing existing symlink: $target"
        rm "$target"
    elif [[ -f "$target" ]]; then
        log_warning "Backing up existing file: $target -> $target.backup"
        mv "$target" "$target.backup"
    fi

    # Create symlink
    log_info "Creating symlink: $description"
    ln -sf "$source" "$target"
    log_success "Created symlink: $target -> $source"
}

# Function to remove symlink
remove_symlink() {
    local target="$1"
    local description="$2"

    if [[ -L "$target" ]]; then
        log_info "Removing symlink: $description"
        rm "$target"
        log_success "Removed symlink: $target"

        # Restore backup if it exists
        if [[ -f "$target.backup" ]]; then
            log_info "Restoring backup: $target.backup -> $target"
            mv "$target.backup" "$target"
            log_success "Restored backup: $target"
        fi
    else
        log_warning "No symlink found at: $target"
    fi
}

# Function to check symlink status
check_symlink() {
    local source="$1"
    local target="$2"
    local description="$3"

    if [[ -L "$target" ]]; then
        local link_target=$(readlink "$target")
        if [[ "$link_target" == "$source" ]]; then
            log_success "✓ $description: $target -> $source"
        else
            log_warning "⚠ $description: $target -> $link_target (should be $source)"
        fi
    elif [[ -f "$target" ]]; then
        log_warning "⚠ $description: $target exists but is not a symlink"
    else
        log_error "✗ $description: $target does not exist"
    fi
}

# Function to show help
show_help() {
    cat <<'EOF'
Simple Dotfiles Symlink Handler

Usage: ./dotfiles.sh [COMMAND]

Commands:
  install     - Create symlinks for all dotfiles
  uninstall   - Remove symlinks and restore backups
  status      - Show status of all symlinks
  zshrc       - Manage .zshrc symlink only
  menu        - Show interactive menu
  help        - Show this help message

Extras:
  - lsd color config: ~/.config/lsd/config.yaml (see https://lsd-rs.github.io/lsd/usage/configuration.html)
  - fzf advanced integration: see .zshrc for keybindings, git, and preview features
  - Full install/uninstall: ./install-symlinks.sh and ./uninstall-symlinks.sh for complete setup

Examples:
  ./dotfiles.sh install
  ./dotfiles.sh status
  ./dotfiles.sh zshrc install
  ./dotfiles.sh uninstall

EOF
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
    echo -e "${CYAN}║                    DOTFILES MANAGER                          ║${NC}"
    echo -e "${CYAN}╠══════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║  ${GREEN}1${NC} │ Install dotfiles (create symlinks)                    ║${NC}"
    echo -e "${CYAN}║  ${GREEN}2${NC} │ Uninstall dotfiles (remove symlinks)                  ║${NC}"
    echo -e "${CYAN}║  ${GREEN}3${NC} │ Check status of all symlinks                          ║${NC}"
    echo -e "${CYAN}║  ${GREEN}4${NC} │ Manage .zshrc symlink only                            ║${NC}"
    echo -e "${CYAN}║  ${GREEN}5${NC} │ Run full installer (install-symlinks.sh)              ║${NC}"
    echo -e "${CYAN}║  ${GREEN}6${NC} │ Run full uninstaller (uninstall-symlinks.sh)          ║${NC}"
    echo -e "${CYAN}║  ${GREEN}7${NC} │ Test cross-platform compatibility                     ║${NC}"
    echo -e "${CYAN}║  ${GREEN}8${NC} │ Setup Debian/Ubuntu server (zsh + dependencies)      ║${NC}"
    echo -e "${CYAN}║  ${GREEN}9${NC} │ Quick fix Debian terminal issues                     ║${NC}"
    echo -e "${CYAN}║  ${GREEN}10${NC} │ Install Starship & Direnv (prompt + env switching)  ║${NC}"
    echo -e "${CYAN}║  ${GREEN}11${NC} │ Show help                                            ║${NC}"
    echo -e "${CYAN}║  ${RED}0${NC} │ Exit                                                   ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo
    echo -e "${YELLOW}Current OS:${NC} $(uname -s) $(uname -r)"
    echo -e "${YELLOW}Current directory:${NC} $(pwd)"
    echo
}

# Function to handle menu selection
handle_menu_selection() {
    local choice="$1"
    
    case "$choice" in
        1)
            log_info "Running: Install dotfiles"
            install_all
            ;;
        2)
            log_info "Running: Uninstall dotfiles"
            uninstall_all
            ;;
        3)
            log_info "Running: Check status"
            status_all
            ;;
        4)
            log_info "Running: Manage .zshrc"
            manage_zshrc_menu
            ;;
        5)
            log_info "Running: Full installer"
            if [[ -x "./install-symlinks.sh" ]]; then
                ./install-symlinks.sh
            else
                log_error "install-symlinks.sh not found or not executable"
            fi
            ;;
        6)
            log_info "Running: Full uninstaller"
            if [[ -x "./uninstall-symlinks.sh" ]]; then
                ./uninstall-symlinks.sh
            else
                log_error "uninstall-symlinks.sh not found or not executable"
            fi
            ;;
        7)
            log_info "Running: Cross-platform test"
            if [[ -x "./test-cross-platform.sh" ]]; then
                ./test-cross-platform.sh
            else
                log_error "test-cross-platform.sh not found or not executable"
            fi
            ;;
        8)
            log_info "Running: Debian/Ubuntu server setup"
            if [[ -x "./setup-debian-zsh.sh" ]]; then
                ./setup-debian-zsh.sh
            else
                log_error "setup-debian-zsh.sh not found or not executable"
            fi
            ;;
        9)
            log_info "Running: Quick Debian terminal fix"
            if [[ -x "./fix-debian-terminal.sh" ]]; then
                ./fix-debian-terminal.sh
            else
                log_error "fix-debian-terminal.sh not found or not executable"
            fi
            ;;
        10)
            log_info "Running: Install Starship & Direnv"
            if [[ -x "./install-starship-direnv.sh" ]]; then
                ./install-starship-direnv.sh
            else
                log_error "install-starship-direnv.sh not found or not executable"
            fi
            ;;
        11)
            show_help
            ;;
        0)
            log_info "Exiting..."
            exit 0
            ;;
        *)
            log_error "Invalid choice: $choice"
            return 1
            ;;
    esac
}

# Function to show .zshrc management submenu
manage_zshrc_menu() {
    # Cross-platform clear command
    if command -v clear >/dev/null 2>&1; then
        clear 2>/dev/null || printf '\033[2J\033[H'
    else
        printf '\033[2J\033[H'
    fi
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                    MANAGE .ZSHRC                             ║${NC}"
    echo -e "${CYAN}╠══════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║  ${GREEN}1${NC} │ Install .zshrc symlink                              ║${NC}"
    echo -e "${CYAN}║  ${GREEN}2${NC} │ Uninstall .zshrc symlink                            ║${NC}"
    echo -e "${CYAN}║  ${GREEN}3${NC} │ Check .zshrc status                                 ║${NC}"
    echo -e "${CYAN}║  ${GREEN}0${NC} │ Back to main menu                                   ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo
    
    read -p "Select option: " zshrc_choice
    echo
    
    case "$zshrc_choice" in
        1)
            create_symlink "$SCRIPT_DIR/.zshrc" "$HOME/.zshrc" ".zshrc"
            ;;
        2)
            remove_symlink "$HOME/.zshrc" ".zshrc"
            ;;
        3)
            check_symlink "$SCRIPT_DIR/.zshrc" "$HOME/.zshrc" ".zshrc"
            ;;
        0)
            return 0
            ;;
        *)
            log_error "Invalid choice: $zshrc_choice"
            ;;
    esac
    
    echo
    read -p "Press Enter to continue..."
}

# Function to run interactive menu
run_menu() {
    while true; do
        show_menu
        read -p "Select option (0-11): " choice
        echo
        
        if handle_menu_selection "$choice"; then
            echo
            read -p "Press Enter to continue..."
        fi
    done
}

# Function to install all dotfiles
install_all() {
    log_info "Installing dotfiles symlinks..."
    log_info "Detected OS: $(uname -s) $(uname -r)"

    # .zshrc
    create_symlink "$SCRIPT_DIR/.zshrc" "$HOME/.zshrc" ".zshrc"

    # Add more dotfiles here as needed
    # create_symlink "$SCRIPT_DIR/.gitconfig" "$HOME/.gitconfig" ".gitconfig"
    # create_symlink "$SCRIPT_DIR/.gitignore_global" "$HOME/.gitignore_global" ".gitignore_global"

    log_success "All dotfiles installed!"
}

# Function to uninstall all dotfiles
uninstall_all() {
    log_info "Uninstalling dotfiles symlinks..."

    # .zshrc
    remove_symlink "$HOME/.zshrc" ".zshrc"

    # Add more dotfiles here as needed
    # remove_symlink "$HOME/.gitconfig" ".gitconfig"
    # remove_symlink "$HOME/.gitignore_global" ".gitignore_global"

    log_success "All dotfiles uninstalled!"
}

# Function to check status of all dotfiles
status_all() {
    log_info "Checking dotfiles status..."

    # .zshrc
    check_symlink "$SCRIPT_DIR/.zshrc" "$HOME/.zshrc" ".zshrc"

    # Add more dotfiles here as needed
    # check_symlink "$SCRIPT_DIR/.gitconfig" "$HOME/.gitconfig" ".gitconfig"
    # check_symlink "$SCRIPT_DIR/.gitignore_global" "$HOME/.gitignore_global" ".gitignore_global"
}

# Function to manage .zshrc specifically
manage_zshrc() {
    local action="$1"

    case "$action" in
    install)
        create_symlink "$SCRIPT_DIR/.zshrc" "$HOME/.zshrc" ".zshrc"
        ;;
    uninstall)
        remove_symlink "$HOME/.zshrc" ".zshrc"
        ;;
    status)
        check_symlink "$SCRIPT_DIR/.zshrc" "$HOME/.zshrc" ".zshrc"
        ;;
    *)
        log_error "Unknown action: $action"
        log_info "Use: ./dotfiles.sh zshrc [install|uninstall|status]"
        exit 1
        ;;
    esac
}

# Main script logic
case "${1:-menu}" in
install)
    install_all
    ;;
uninstall)
    uninstall_all
    ;;
status)
    status_all
    ;;
zshrc)
    manage_zshrc "$2"
    ;;
menu)
    run_menu
    ;;
help | --help | -h)
    show_help
    ;;
*)
    log_error "Unknown command: $1"
    show_help
    exit 1
    ;;
esac

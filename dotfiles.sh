#!/bin/zsh

# Simple Dotfiles Symlink Handler
# Manages symlinks for dotfiles from the repository

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

# Function to install all dotfiles
install_all() {
    log_info "Installing dotfiles symlinks..."

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
case "${1:-help}" in
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
help | --help | -h)
    show_help
    ;;
*)
    log_error "Unknown command: $1"
    show_help
    exit 1
    ;;
esac

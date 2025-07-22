#!/usr/bin/env bash
# Uninstall script for dotfiles symlinks
# Removes symlinks and restores backups
# Cross-platform compatible: macOS, Linux, WSL2

set -e

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

# Function to remove symlink and restore backup
remove_symlink() {
    local target="$1"
    local description="$2"

    if [[ -L "$target" ]]; then
        log_info "Removing symlink: $description"
        rm "$target"
        log_success "Removed symlink: $target"

        # Restore backup if it exists
        local backup_pattern="$target.backup.*"
        local latest_backup=$(ls -t $backup_pattern 2>/dev/null | head -1)
        if [[ -n "$latest_backup" ]]; then
            log_info "Restoring backup: $latest_backup -> $target"
            mv "$latest_backup" "$target"
            log_success "Restored backup: $target"
        fi
    elif [[ -e "$target" ]]; then
        log_warning "File exists but is not a symlink: $target"
    else
        log_warning "No symlink found at: $target"
    fi
}

# Function to remove directory symlink
remove_dir_symlink() {
    local target="$1"
    local description="$2"

    if [[ -L "$target" ]]; then
        log_info "Removing directory symlink: $description"
        rm "$target"
        log_success "Removed directory symlink: $target"
    elif [[ -d "$target" ]]; then
        log_warning "Directory exists but is not a symlink: $target"
    else
        log_warning "No directory symlink found at: $target"
    fi
}

# Confirmation prompt (cross-platform)
echo -e "${YELLOW}This will remove all dotfiles symlinks and restore backups.${NC}"
read -p "Are you sure you want to continue? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    log_info "Uninstall cancelled."
    exit 0
fi

# Main uninstallation
log_info "Uninstalling dotfiles symlinks..."
log_info "Detected OS: $(uname -s) $(uname -r)"

# Basic dotfiles
remove_symlink "$HOME/.zshrc" ".zshrc"
remove_symlink "$HOME/.gitconfig" ".gitconfig"
remove_symlink "$HOME/.gitignore_global" ".gitignore_global"

# Config directories
remove_dir_symlink "$HOME/.config/lsd" "lsd config"
remove_symlink "$HOME/.config/starship.toml" "starship config"
remove_dir_symlink "$HOME/.config/ghostty" "ghostty config"

# Add more config directories as needed
# remove_dir_symlink "$HOME/.config/nvim" "nvim config"
# remove_dir_symlink "$HOME/.config/alacritty" "alacritty config"

log_success "All symlinks uninstalled successfully!"
log_info "You may need to restart your shell or source your original .zshrc"

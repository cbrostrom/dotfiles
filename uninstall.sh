#!/usr/bin/env bash

# Dotfiles Uninstaller v1.0
# Removes dotfiles symlinks and optionally restores backups

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

# Function to remove symlink and restore backup
remove_symlink() {
    local target="$1"
    local description="$2"

    if [[ -L "$target" ]]; then
        log_info "Removing symlink: $description"
        rm "$target"
        log_success "Removed symlink: $target"

        # Restore backup if it exists
        if [[ -f "$target.backup"* ]]; then
            local backup_file=$(ls "$target.backup"* | head -1)
            log_info "Restoring backup: $backup_file -> $target"
            mv "$backup_file" "$target"
            log_success "Restored backup: $target"
        fi
    else
        log_warning "No symlink found at: $target"
    fi
}

# Function to show help
show_help() {
    cat <<'EOF'
Dotfiles Uninstaller v1.0

Usage: ./uninstall.sh [OPTIONS]

Options:
  --help, -h          Show this help message
  --keep-backups      Keep backup files (don't restore them)
  --dry-run           Show what would be removed without actually removing

Examples:
  ./uninstall.sh                    # Remove symlinks and restore backups
  ./uninstall.sh --keep-backups     # Remove symlinks but keep backups
  ./uninstall.sh --dry-run          # Preview what would be removed

This script will:
1. Remove all dotfiles symlinks
2. Restore original files from backups (unless --keep-backups is used)
3. Clean up empty directories

EOF
}

# Function to perform dry run
dry_run() {
    log_info "=== DRY RUN - Preview of uninstallation ==="
    
    log_info ""
    log_info "Would remove symlinks:"
    echo "  - ~/.zshrc"
    echo "  - ~/.gitconfig"
    echo "  - ~/.gitignore_global"
    echo "  - ~/.config/starship.toml"
    echo "  - ~/.config/ghostty/" # if macOS
    echo "  - Windows Terminal settings.json" # if WSL
    
    log_info ""
    log_info "Would restore backups:"
    echo "  - Any .backup.* files found"
    
    log_success "Dry run complete - no changes made"
}

# Main uninstallation function
main_uninstallation() {
    local keep_backups=false
    local dry_run_mode=false
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --help|-h)
                show_help
                exit 0
                ;;
            --keep-backups)
                keep_backups=true
                shift
                ;;
            --dry-run)
                dry_run_mode=true
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    if $dry_run_mode; then
        dry_run
        exit 0
    fi
    
    log_info "=== Dotfiles Uninstaller v1.0 ==="
    
    # Check if running as root
    if [[ $EUID -eq 0 ]]; then
        log_error "Please do not run this script as root"
        exit 1
    fi
    
    log_info "Removing dotfiles symlinks..."
    
    # Basic dotfiles
    remove_symlink "$HOME/.zshrc" ".zshrc"
    remove_symlink "$HOME/.gitconfig" ".gitconfig"
    remove_symlink "$HOME/.gitignore_global" ".gitignore_global"

    # Config directories
    remove_symlink "$HOME/.config/starship.toml" "starship config"
    
    # Platform-specific configs
    if [[ "$OSTYPE" == "darwin"* ]]; then
        remove_symlink "$HOME/.config/ghostty" "ghostty config"
    fi

    # Windows Terminal (if on WSL)
    if grep -q Microsoft /proc/version 2>/dev/null; then
        # Try multiple possible Windows Terminal paths
        WINDOWS_TERMINAL_PATHS=(
            "$APPDATA/Packages/Microsoft.WindowsTerminal_8wekyb3d8bbwe/LocalState"
            "/mnt/c/Users/$USER/AppData/Local/Packages/Microsoft.WindowsTerminal_8wekyb3d8bbwe/LocalState"
            "/mnt/c/Users/$USERNAME/AppData/Local/Packages/Microsoft.WindowsTerminal_8wekyb3d8bbwe/LocalState"
        )

        for WINDOWS_TERMINAL_DIR in "${WINDOWS_TERMINAL_PATHS[@]}"; do
            if [[ -d "$WINDOWS_TERMINAL_DIR" ]]; then
                remove_symlink "$WINDOWS_TERMINAL_DIR/settings.json" "Windows Terminal config"
                break
            fi
        done
    fi
    
    # Clean up empty directories
    log_info "Cleaning up empty directories..."
    rmdir "$HOME/.config/ghostty" 2>/dev/null || true
    
    log_info ""
    log_success "=== Uninstallation Complete! ==="
    log_info ""
    log_info "Next steps:"
    log_info "1. Log out and log back in (or restart your terminal)"
    log_info "2. Your original shell configuration will be restored"
    log_info ""
    log_info "If you want to change your default shell back to bash:"
    log_info "  chsh -s /bin/bash"
}

# Run uninstallation
main_uninstallation "$@" 
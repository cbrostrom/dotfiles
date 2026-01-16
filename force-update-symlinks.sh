#!/usr/bin/env bash

# Force Update Symlinks Script
# Forces recreation of all symlinks to ensure they're up to date

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

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log_info "=== Force Update Symlinks ==="
log_info "Script directory: $SCRIPT_DIR"
log_info "Home directory: $HOME"

# Function to force create symlink
force_create_symlink() {
    local source="$1"
    local target="$2"
    local description="$3"

    if [[ ! -e "$source" ]]; then
        log_warning "Source not found, skipping: $source"
        return 0
    fi

    # Remove existing target (symlink or file)
    if [[ -e "$target" ]]; then
        log_info "Removing existing target: $target"
        rm -rf "$target"
    fi

    # Create target directory if it doesn't exist
    local target_dir="$(dirname "$target")"
    if [[ ! -d "$target_dir" ]]; then
        log_info "Creating directory: $target_dir"
        mkdir -p "$target_dir"
    fi

    # Create symlink
    log_info "Creating symlink: $description"
    ln -sf "$source" "$target"
    
    if [[ -L "$target" ]]; then
        local link_target=$(readlink "$target")
        log_success "✓ Created symlink: $target -> $link_target"
    else
        log_error "✗ Failed to create symlink: $target"
    fi
}

# Force update all symlinks
log_info ""
log_info "=== Updating Symlinks ==="

# Basic dotfiles
force_create_symlink "$SCRIPT_DIR/.zshrc" "$HOME/.zshrc" ".zshrc"
force_create_symlink "$SCRIPT_DIR/.gitconfig" "$HOME/.gitconfig" ".gitconfig"
force_create_symlink "$SCRIPT_DIR/.gitignore_global" "$HOME/.gitignore_global" ".gitignore_global"

# Config directories
force_create_symlink "$SCRIPT_DIR/.config/starship.toml" "$HOME/.config/starship.toml" "starship config"

# Platform-specific configs
if [[ "$OSTYPE" == "darwin"* ]]; then
    force_create_symlink "$SCRIPT_DIR/.config/ghostty" "$HOME/.config/ghostty" "ghostty config"
fi

# Windows Terminal (if on WSL)
if grep -q Microsoft /proc/version 2>/dev/null; then
    # Try multiple possible Windows Terminal paths
    WINDOWS_TERMINAL_PATHS=(
        "$APPDATA/Packages/Microsoft.WindowsTerminal_8wekyb3d8bbwe/LocalState"
        "/mnt/c/Users/$USER/AppData/Local/Packages/Microsoft.WindowsTerminal_8wekyb3d8bbwe/LocalState"
        "/mnt/c/Users/$USERNAME/AppData/Local/Packages/Microsoft.WindowsTerminal_8wekyb3d8bbwe/LocalState"
    )

    WINDOWS_TERMINAL_FOUND=false
    for WINDOWS_TERMINAL_DIR in "${WINDOWS_TERMINAL_PATHS[@]}"; do
        if [[ -d "$WINDOWS_TERMINAL_DIR" ]]; then
            log_info "Found Windows Terminal directory: $WINDOWS_TERMINAL_DIR"
            force_create_symlink "$SCRIPT_DIR/.config/windows-terminal/settings.json" "$WINDOWS_TERMINAL_DIR/settings.json" "Windows Terminal config"
            WINDOWS_TERMINAL_FOUND=true
            break
        fi
    done

    if [[ "$WINDOWS_TERMINAL_FOUND" == "false" ]]; then
        log_warning "Windows Terminal directory not found, skipping Windows Terminal config"
    fi
fi

log_info ""
log_success "=== Symlink Update Complete ==="
log_info ""
log_info "Run './status.sh' to verify all symlinks are correct"
log_info "Run 'source ~/.zshrc' to reload your shell configuration" 
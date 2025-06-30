#!/bin/zsh
# Install script for dotfiles symlinks
# Creates symlinks for all dotfiles and config directories

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
if [[ -n "$BASH_SOURCE" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
else
    SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
fi

# Function to create symlink with backup
create_symlink() {
    local source="$1"
    local target="$2"
    local description="$3"

    if [[ ! -e "$source" ]]; then
        log_warning "Source not found, skipping: $source"
        return 0
    fi

    # Create target directory if it doesn't exist
    local target_dir="$(dirname "$target")"
    if [[ ! -d "$target_dir" ]]; then
        log_info "Creating directory: $target_dir"
        mkdir -p "$target_dir"
    fi

    # Handle existing target
    if [[ -L "$target" ]]; then
        log_info "Removing existing symlink: $target"
        rm "$target"
    elif [[ -e "$target" ]]; then
        local backup="$target.backup.$(date +%Y%m%d_%H%M%S)"
        log_warning "Backing up existing file: $target -> $backup"
        mv "$target" "$backup"
    fi

    # Create relative symlink
    local rel_source
    if command -v realpath >/dev/null 2>&1; then
        rel_source=$(realpath --relative-to="$(dirname "$target")" "$source" 2>/dev/null || echo "$source")
    else
        # Fallback using Python for relative path calculation
        rel_source=$(python3 -c "import os.path; print(os.path.relpath('$source', os.path.dirname('$target')))" 2>/dev/null || echo "$source")
    fi

    # Create symlink
    log_info "Creating symlink: $description"
    ln -sf "$rel_source" "$target"
    log_success "Created symlink: $target -> $rel_source"
}

# Main installation
log_info "Installing dotfiles symlinks..."

# Basic dotfiles
create_symlink "$SCRIPT_DIR/.zshrc" "$HOME/.zshrc" ".zshrc"
create_symlink "$SCRIPT_DIR/.gitconfig" "$HOME/.gitconfig" ".gitconfig"
create_symlink "$SCRIPT_DIR/.gitignore_global" "$HOME/.gitignore_global" ".gitignore_global"

# Config directories
create_symlink "$SCRIPT_DIR/.config/lsd" "$HOME/.config/lsd" "lsd config"
create_symlink "$SCRIPT_DIR/.config/starship.toml" "$HOME/.config/starship.toml" "starship config"

# Add more config directories as needed
# create_symlink "$SCRIPT_DIR/.config/nvim" "$HOME/.config/nvim" "nvim config"
# create_symlink "$SCRIPT_DIR/.config/alacritty" "$HOME/.config/alacritty" "alacritty config"

log_success "All symlinks installed successfully!"
log_info "You may need to restart your shell or run: source ~/.zshrc"

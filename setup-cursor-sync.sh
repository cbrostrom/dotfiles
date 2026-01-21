#!/usr/bin/env bash

# Setup Cursor Settings Sync via Dotfiles
# Creates symlinks from Cursor User directory to dotfiles for git sync
# Cross-platform: macOS, Linux, WSL2

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

# OS Detection
if [[ "$OSTYPE" == "darwin"* ]]; then
    IS_MACOS=true
    CURSOR_USER_DIR="$HOME/Library/Application Support/Cursor/User"
    CURSOR_EXTENSIONS_DIR="$HOME/.cursor/extensions"
elif [[ "$OSTYPE" == "linux-gnu"* ]] || [[ "$OSTYPE" == "linux"* ]]; then
    IS_MACOS=false
    CURSOR_USER_DIR="$HOME/.config/Cursor/User"
    CURSOR_EXTENSIONS_DIR="$HOME/.cursor/extensions"
else
    log_error "Unsupported OS: $OSTYPE"
    exit 1
fi

# Dotfiles Cursor config directory
DOTFILES_CURSOR_DIR="$SCRIPT_DIR/.config/cursor"

log_info "=== Cursor Settings Sync Setup ==="
log_info "Cursor User directory: $CURSOR_USER_DIR"
log_info "Cursor Extensions directory: $CURSOR_EXTENSIONS_DIR"
log_info "Dotfiles Cursor directory: $DOTFILES_CURSOR_DIR"

# Check if Cursor User directory exists
if [[ ! -d "$CURSOR_USER_DIR" ]]; then
    log_error "Cursor User directory not found: $CURSOR_USER_DIR"
    log_error "Is Cursor installed?"
    exit 1
fi

# Check if dotfiles cursor config exists
if [[ ! -d "$DOTFILES_CURSOR_DIR" ]]; then
    log_error "Dotfiles Cursor config not found: $DOTFILES_CURSOR_DIR"
    log_error "Please run this script from the dotfiles directory"
    exit 1
fi

# Function to create backup
create_backup() {
    local file="$1"
    if [[ -e "$file" ]] && [[ ! -L "$file" ]]; then
        local backup="${file}.backup.$(date +%Y%m%d_%H%M%S)"
        log_info "Creating backup: $backup"
        mv "$file" "$backup"
        log_success "Backup created: $backup"
    fi
}

# Function to create symlink
create_symlink() {
    local source="$1"
    local target="$2"
    local description="$3"
    
    # Check if source exists in dotfiles
    if [[ ! -e "$source" ]]; then
        log_warning "Source not found, skipping: $source"
        return 0
    fi
    
    # Check if target is already a symlink pointing to the correct location
    if [[ -L "$target" ]]; then
        local current_target=$(readlink "$target")
        if [[ "$current_target" == "$source" ]]; then
            log_success "✓ $description already correctly linked"
            return 0
        else
            log_info "Updating existing symlink: $description"
            rm "$target"
        fi
    elif [[ -e "$target" ]]; then
        # Backup existing file
        create_backup "$target"
    fi
    
    # Create symlink
    log_info "Creating symlink: $description"
    ln -sf "$source" "$target"
    log_success "Created symlink: $target -> $source"
}

# Create symlinks for Cursor settings
log_info ""
log_info "Creating symlinks..."

create_symlink \
    "$DOTFILES_CURSOR_DIR/settings.json" \
    "$CURSOR_USER_DIR/settings.json" \
    "settings.json"

create_symlink \
    "$DOTFILES_CURSOR_DIR/keybindings.json" \
    "$CURSOR_USER_DIR/keybindings.json" \
    "keybindings.json"

create_symlink \
    "$DOTFILES_CURSOR_DIR/snippets" \
    "$CURSOR_USER_DIR/snippets" \
    "snippets/"

# NOTE: We do NOT symlink extensions.json!
# Cursor needs to manage its own internal extensions.json with full metadata.
# Our dotfiles version is a simplified list for tracking/reinstalling only.
log_info ""
log_info "Extensions sync: Using separate tracking list (no symlink)"
log_info "  - Cursor manages: ~/.cursor/extensions/extensions.json (internal metadata)"
log_info "  - Dotfiles tracks: .config/cursor/extensions.json (simplified list)"
log_info "  - Use ./update-cursor-extensions.sh to sync the list after installing new extensions"

log_info ""
log_success "=== Cursor Settings Sync Setup Complete! ==="
log_info ""
log_info "Your Cursor settings are now synced via dotfiles:"
log_info "  - settings.json"
log_info "  - keybindings.json"
log_info "  - snippets/"
log_info "  - extensions.json (list of installed extensions)"
log_info ""
log_info "Note: Extension files are NOT synced, only the list (extensions.json)"
log_info "You'll need to reinstall extensions on new machines, but the list is preserved"
log_info ""
log_info "Changes in Cursor will be reflected in dotfiles automatically"
log_info "Commit and push changes to sync across machines"
log_info ""

# Ask if user wants to install extensions now
if [[ -f "$DOTFILES_CURSOR_DIR/extensions.json" ]]; then
    EXTENSION_COUNT=$(jq '. | length' "$DOTFILES_CURSOR_DIR/extensions.json" 2>/dev/null || echo "0")
    
    if [[ "$EXTENSION_COUNT" -gt 0 ]]; then
        log_info "Found $EXTENSION_COUNT extensions in extensions.json"
        echo ""
        echo -n "Do you want to install all extensions now? [y/N]: "
        read -r response
        
        if [[ "$response" =~ ^[Yy]$ ]]; then
            log_info ""
            log_info "Installing extensions..."
            if [[ -f "$SCRIPT_DIR/install-cursor-extensions.sh" ]]; then
                bash "$SCRIPT_DIR/install-cursor-extensions.sh"
            else
                log_error "install-cursor-extensions.sh not found"
                log_info "Run manually: ./install-cursor-extensions.sh"
            fi
        else
            log_info "Skipping extension installation"
            log_info "To install extensions later, run: ./install-cursor-extensions.sh"
        fi
    fi
fi

log_info ""
log_info "To verify symlinks:"
log_info "  ls -la \"$CURSOR_USER_DIR\" | grep -E '(settings|keybindings|snippets)'"
log_info "  ls -la \"$CURSOR_EXTENSIONS_DIR\" | grep extensions.json"
log_info ""
log_info "To update extensions list after installing new extensions:"
log_info "  ./update-cursor-extensions.sh"


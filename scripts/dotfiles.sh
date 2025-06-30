#!/bin/bash

# Dotfiles Manager
# Supports macOS and WSL2 Ubuntu

set -e # Re-enabled with better error handling

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration file
CONFIG_FILE="$(dirname "$0")/dotfiles.conf"
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DEBUG_MODE=false

# Parse debug flag
if [[ "$1" == "--debug" ]]; then
    DEBUG_MODE=true
    shift
fi

# Default configuration
DEFAULT_CONFIG="# Dotfiles Configuration
# Format: source_file:target_location:description
# Use ~ for home directory
# Use .config/ for config directory

# Shell configuration
.zshrc:~/.zshrc:Zsh configuration
.bashrc:~/.bashrc:Bash configuration

# Git configuration
.gitconfig:~/.gitconfig:Git configuration
.gitignore_global:~/.gitignore_global:Global gitignore

# SSH configuration
.ssh/config:~/.ssh/config:SSH configuration
.ssh/id_rsa:~/.ssh/id_rsa:SSH private key
.ssh/id_rsa.pub:~/.ssh/id_rsa.pub:SSH public key

# Editor configuration
.vimrc:~/.vimrc:Vim configuration
.vim/init.vim:~/.vim/init.vim:Vim init file
.config/nvim/init.vim:~/.config/nvim/init.vim:Neovim configuration

# Terminal configuration
.config/alacritty/alacritty.yml:~/.config/alacritty/alacritty.yml:Alacritty configuration
.config/kitty/kitty.conf:~/.config/kitty/kitty.conf:Kitty configuration

# Development tools
.config/tmux/tmux.conf:~/.config/tmux/tmux.conf:Tmux configuration
.tmux.conf:~/.tmux.conf:Tmux configuration (legacy)

# Package managers
.config/npm/npmrc:~/.config/npm/npmrc:NPM configuration
.yarnrc:~/.yarnrc:Yarn configuration

# Other tools
.config/gh/config.yml:~/.config/gh/config.yml:GitHub CLI configuration
.config/bat/config:~/.config/bat/config:Bat configuration
.config/fd/ignore:~/.config/fd/ignore:Fd ignore file
"

# Functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

detect_os() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macos"
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if grep -q Microsoft /proc/version 2>/dev/null; then
            echo "wsl"
        else
            echo "linux"
        fi
    else
        echo "unknown"
    fi
}

create_backup() {
    local target="$1"
    if [[ -L "$target" ]]; then
        log_info "Removing existing symlink: $target"
        rm "$target"
    elif [[ -f "$target" ]] || [[ -d "$target" ]]; then
        local backup="${target}.backup.$(date +%Y%m%d_%H%M%S)"
        log_warning "Backing up existing file: $target -> $backup"
        mv "$target" "$backup"
    fi
}

create_symlink() {
    local source="$1"
    local target="$2"
    local description="$3"

    # Debug logging
    if $DEBUG_MODE; then
        log_info "DEBUG: Creating symlink for $source -> $target"
        log_info "DEBUG: Script directory: $SCRIPT_DIR"
        log_info "DEBUG: Source absolute: $SCRIPT_DIR/$source"
        log_info "DEBUG: Target: $target"
    fi

    # Expand ~ to home directory
    target="${target/#\~/$HOME}"

    # Ensure target directory exists
    local target_dir=$(dirname "$target")
    if [[ ! -d "$target_dir" ]]; then
        log_info "Creating directory: $target_dir"
        mkdir -p "$target_dir"
    fi

    if $DEBUG_MODE; then
        log_info "DEBUG: Target directory: $target_dir"
        log_info "DEBUG: Target directory exists: $([[ -d "$target_dir" ]] && echo "YES" || echo "NO")"
    fi

    # Create backup if target exists
    create_backup "$target"

    # Calculate relative path using Python (most reliable cross-platform method)
    local source_abs="$SCRIPT_DIR/$source"
    local relative_source

    if $DEBUG_MODE; then
        log_info "DEBUG: Source absolute path: $source_abs"
        log_info "DEBUG: Source file exists: $([[ -f "$source_abs" ]] && echo "YES" || echo "NO")"
    fi

    # Use Python for reliable relative path calculation
    if command -v python3 >/dev/null 2>&1; then
        if $DEBUG_MODE; then
            log_info "DEBUG: Using Python3 for relative path calculation"
        fi
        relative_source=$(python3 -c "
import os.path
try:
    print(os.path.relpath('$source_abs', '$target_dir'))
except:
    print('dotfiles/$source')
")
    elif command -v python >/dev/null 2>&1; then
        if $DEBUG_MODE; then
            log_info "DEBUG: Using Python for relative path calculation"
        fi
        relative_source=$(python -c "
import os.path
try:
    print(os.path.relpath('$source_abs', '$target_dir'))
except:
    print('dotfiles/$source')
")
    elif command -v node >/dev/null 2>&1; then
        if $DEBUG_MODE; then
            log_info "DEBUG: Using Node.js for relative path calculation"
        fi
        relative_source=$(node -e "
const path = require('path');
try {
    console.log(path.relative('$target_dir', '$source_abs'));
} catch (e) {
    console.log('dotfiles/$source');
}
")
    else
        if $DEBUG_MODE; then
            log_info "DEBUG: Using fallback calculation"
        fi
        # Fallback: simple calculation for common cases
        if [[ "$target_dir" == "$HOME" ]]; then
            relative_source="dotfiles/$source"
        elif [[ "$target_dir" == "$HOME/.config" ]]; then
            relative_source="../dotfiles/$source"
        elif [[ "$target_dir" == "$HOME/.config/zsh" ]]; then
            relative_source="../../dotfiles/$source"
        elif [[ "$target_dir" == "$HOME/.config/ghostty" ]]; then
            relative_source="../../dotfiles/$source"
        else
            # Generic fallback
            relative_source="dotfiles/$source"
        fi
    fi

    if $DEBUG_MODE; then
        log_info "DEBUG: Calculated relative path: $relative_source"
    fi

    log_info "Creating symlink: $relative_source -> $target"

    # Try multiple methods to create symlink
    local symlink_created=false

    # Method 1: Python
    if ! $symlink_created && command -v python3 >/dev/null 2>&1; then
        if $DEBUG_MODE; then
            log_info "DEBUG: Trying Python3 symlink creation"
        fi
        if python3 -c "
import os
try:
    os.symlink('$relative_source', '$target')
    print('SUCCESS')
except Exception as e:
    print('ERROR: ' + str(e))
    exit(1)
" 2>/dev/null; then
            log_success "Linked $source -> $target ($description) [Python]"
            symlink_created=true
        else
            if $DEBUG_MODE; then
                log_info "DEBUG: Python3 symlink creation failed"
            fi
        fi
    fi

    # Method 2: Node.js
    if ! $symlink_created && command -v node >/dev/null 2>&1; then
        if $DEBUG_MODE; then
            log_info "DEBUG: Trying Node.js symlink creation"
        fi
        if node -e "
const fs = require('fs');
try {
    fs.symlinkSync('$relative_source', '$target');
    console.log('SUCCESS');
} catch (e) {
    console.log('ERROR: ' + e.message);
    process.exit(1);
}
" 2>/dev/null; then
            log_success "Linked $source -> $target ($description) [Node.js]"
            symlink_created=true
        else
            if $DEBUG_MODE; then
                log_info "DEBUG: Node.js symlink creation failed"
            fi
        fi
    fi

    # Method 3: Traditional ln (fallback)
    if ! $symlink_created; then
        if $DEBUG_MODE; then
            log_info "DEBUG: Trying traditional ln symlink creation"
        fi
        if ln -sf "$relative_source" "$target"; then
            log_success "Linked $source -> $target ($description) [ln]"
            symlink_created=true
        else
            if $DEBUG_MODE; then
                log_info "DEBUG: Traditional ln symlink creation failed"
            fi
        fi
    fi

    # If all methods failed
    if ! $symlink_created; then
        log_error "Failed to link $source -> $target (all methods failed)"
        if $DEBUG_MODE; then
            log_info "DEBUG: All symlink creation methods failed"
            log_info "DEBUG: Final target: $target"
            log_info "DEBUG: Final relative source: $relative_source"
        fi
        return 1
    fi

    if $DEBUG_MODE; then
        log_info "DEBUG: Symlink created successfully"
        log_info "DEBUG: Verifying symlink: $(readlink "$target" 2>/dev/null || echo "FAILED")"
    fi
}

install_dotfiles() {
    log_info "Installing dotfiles..."
    log_info "Script directory: $SCRIPT_DIR"
    log_info "Config file: $CONFIG_FILE"

    if [[ ! -f "$CONFIG_FILE" ]]; then
        log_warning "Configuration file not found. Creating default configuration..."
        echo "$DEFAULT_CONFIG" >"$CONFIG_FILE"
    fi

    local count=0
    local errors=0

    while IFS=: read -r source target description; do
        # Skip comments and empty lines
        [[ "$source" =~ ^[[:space:]]*# ]] && continue
        [[ -z "$source" ]] && continue

        # Skip lines that start with # even if they contain colons
        if [[ "$source" == "#"* ]] || [[ "$target" == "#"* ]]; then
            continue
        fi

        # Trim whitespace
        source=$(echo "$source" | xargs)
        target=$(echo "$target" | xargs)
        description=$(echo "$description" | xargs)

        if $DEBUG_MODE; then
            log_info "DEBUG: About to process: '$source' -> '$target'"
        fi

        log_info "Processing: $source -> $target"

        if [[ -f "$SCRIPT_DIR/$source" ]]; then
            if $DEBUG_MODE; then
                log_info "DEBUG: Source file exists, calling create_symlink"
            fi
            if create_symlink "$source" "$target" "$description"; then
                if $DEBUG_MODE; then
                    log_info "DEBUG: create_symlink succeeded for $source"
                fi
                ((count++))
            else
                if $DEBUG_MODE; then
                    log_info "DEBUG: create_symlink failed for $source"
                fi
                ((errors++))
            fi
        else
            if $DEBUG_MODE; then
                log_info "DEBUG: Source file not found: $SCRIPT_DIR/$source"
            fi
            log_warning "Source file not found: $SCRIPT_DIR/$source"
            ((errors++))
        fi

        if $DEBUG_MODE; then
            log_info "DEBUG: Finished processing $source, count=$count, errors=$errors"
        fi
    done <"$CONFIG_FILE"

    if [[ $errors -eq 0 ]]; then
        log_success "Successfully linked $count dotfiles"
        echo
        log_info "Next steps:"
        log_info "  1. Restart your shell or run: source ~/.zshrc"
        log_info "  2. Install tools (optional): ./scripts/install-tools.sh"
        log_info "  3. Run diagnostics: ./scripts/diagnose.sh"
    else
        log_warning "Linked $count dotfiles with $errors errors"
    fi
}

uninstall_dotfiles() {
    log_info "Uninstalling dotfiles..."

    if [[ ! -f "$CONFIG_FILE" ]]; then
        log_error "Configuration file not found: $CONFIG_FILE"
        return 1
    fi

    # Ask user what level of cleanup they want
    echo -e "\n${YELLOW}Cleanup Options:${NC}"
    echo "1. Remove symlinks only (safe)"
    echo "2. Remove symlinks + restore backups"
    echo "3. Full cleanup (remove symlinks + backups + installed tools)"
    echo ""
    read -p "Select cleanup level (1-3): " cleanup_level

    case $cleanup_level in
    1)
        cleanup_symlinks_only
        ;;
    2)
        cleanup_symlinks_and_backups
        ;;
    3)
        cleanup_full
        ;;
    *)
        log_warning "Invalid selection. Using safe mode (symlinks only)."
        cleanup_symlinks_only
        ;;
    esac
}

cleanup_symlinks_only() {
    log_info "Removing symlinks only..."
    local count=0

    while IFS=: read -r source target description; do
        # Skip comments and empty lines
        [[ "$source" =~ ^[[:space:]]*# ]] && continue
        [[ -z "$source" ]] && continue

        # Trim whitespace
        target=$(echo "$target" | xargs)
        target="${target/#\~/$HOME}"

        if [[ -L "$target" ]]; then
            if rm "$target"; then
                log_success "Removed symlink: $target"
                ((count++))
            else
                log_error "Failed to remove symlink: $target"
            fi
        fi
    done <"$CONFIG_FILE"

    log_success "Removed $count symlinks"
}

cleanup_symlinks_and_backups() {
    log_info "Removing symlinks and restoring backups..."
    local count=0
    local restored=0

    while IFS=: read -r source target description; do
        # Skip comments and empty lines
        [[ "$source" =~ ^[[:space:]]*# ]] && continue
        [[ -z "$source" ]] && continue

        # Trim whitespace
        target=$(echo "$target" | xargs)
        target="${target/#\~/$HOME}"

        # Remove symlink
        if [[ -L "$target" ]]; then
            if rm "$target"; then
                log_success "Removed symlink: $target"
                ((count++))
            else
                log_error "Failed to remove symlink: $target"
                continue
            fi
        fi

        # Restore backup if it exists
        local backup_files=($(ls -1 "${target}.backup."* 2>/dev/null | sort -r))
        if [[ ${#backup_files[@]} -gt 0 ]]; then
            local latest_backup="${backup_files[0]}"
            if mv "$latest_backup" "$target"; then
                log_success "Restored backup: $latest_backup -> $target"
                ((restored++))
            else
                log_error "Failed to restore backup: $latest_backup"
            fi
        fi
    done <"$CONFIG_FILE"

    log_success "Removed $count symlinks and restored $restored backups"
}

cleanup_full() {
    log_warning "This will remove symlinks, backups, and uninstall tools!"
    read -p "Are you sure you want to proceed? (y/N): " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        log_info "Full cleanup cancelled"
        return
    fi

    # First do symlinks and backups
    cleanup_symlinks_and_backups

    # Then uninstall tools
    log_info "Uninstalling installed tools..."

    # Detect OS for tool removal
    local os=$(detect_os)

    if [[ "$os" == "macos" ]]; then
        # macOS - use Homebrew
        if command -v brew &>/dev/null; then
            log_info "Uninstalling tools via Homebrew..."
            brew uninstall lsd bat ripgrep fd fzf lazygit tealdeer atuin direnv asdf starship htop ncdu procs ripgrep-all git-delta git-fuzzy 2>/dev/null || true
        fi
    elif [[ "$os" == "linux" ]] || [[ "$os" == "wsl" ]]; then
        # Linux/WSL - use apt
        log_info "Uninstalling tools via apt..."
        sudo apt remove -y lsd bat ripgrep fd-find fzf lazygit tldr direnv htop ncdu procs ripgrep-all git-delta 2>/dev/null || true
        sudo apt autoremove -y 2>/dev/null || true
    fi

    # Remove manually installed tools
    log_info "Removing manually installed tools..."

    # Remove atuin (if installed via script)
    if [[ -d "$HOME/.local/share/atuin" ]]; then
        rm -rf "$HOME/.local/share/atuin"
        log_success "Removed atuin"
    fi

    # Remove asdf (if installed via script)
    if [[ -d "$HOME/.asdf" ]]; then
        rm -rf "$HOME/.asdf"
        log_success "Removed asdf"
    fi

    # Remove starship (if installed via script)
    if [[ -f "$HOME/.local/bin/starship" ]]; then
        rm -f "$HOME/.local/bin/starship"
        log_success "Removed starship"
    fi

    # Remove zinit
    if [[ -d "$HOME/.local/share/zinit" ]]; then
        rm -rf "$HOME/.local/share/zinit"
        log_success "Removed zinit"
    fi

    log_success "Full cleanup completed"
}

list_dotfiles() {
    log_info "Current dotfiles status:"

    if [[ ! -f "$CONFIG_FILE" ]]; then
        log_error "Configuration file not found: $CONFIG_FILE"
        return 1
    fi

    printf "%-30s %-40s %-20s %s\n" "SOURCE" "TARGET" "STATUS" "DESCRIPTION"
    printf "%-30s %-40s %-20s %s\n" "------" "------" "------" "-----------"

    while IFS=: read -r source target description; do
        # Skip comments and empty lines
        [[ "$source" =~ ^[[:space:]]*# ]] && continue
        [[ -z "$source" ]] && continue

        # Trim whitespace
        source=$(echo "$source" | xargs)
        target=$(echo "$target" | xargs)
        description=$(echo "$description" | xargs)
        target="${target/#\~/$HOME}"

        local status
        if [[ -L "$target" ]]; then
            if [[ "$(readlink "$target")" == "$SCRIPT_DIR/$source" ]]; then
                status="${GREEN}LINKED${NC}"
            else
                status="${YELLOW}WRONG LINK${NC}"
            fi
        elif [[ -f "$target" ]] || [[ -d "$target" ]]; then
            status="${YELLOW}EXISTS${NC}"
        else
            status="${RED}MISSING${NC}"
        fi

        printf "%-30s %-40s %-20s %s\n" "$source" "$target" "$status" "$description"
    done <"$CONFIG_FILE"
}

show_help() {
    cat <<EOF
Dotfiles Manager - Manage your dotfiles across macOS and WSL2 Ubuntu

Usage: $(basename "$0") [COMMAND] [OPTIONS]

Commands:
    install, i     Install/symlink all dotfiles
    uninstall, u   Remove symlinks with cleanup options:
                   - Safe: Remove symlinks only
                   - Restore: Remove symlinks + restore backups
                   - Full: Remove symlinks + backups + uninstall tools
    list, l        Show status of all dotfiles
    init           Initialize configuration file
    help, h        Show this help message

Options:
    --debug        Enable debug mode for troubleshooting
    --config FILE  Use custom configuration file (default: dotfiles.conf)

Examples:
    $(basename "$0") install
    $(basename "$0") --debug install
    $(basename "$0") list
    $(basename "$0") --config my-config.conf install

Configuration:
    Edit $CONFIG_FILE to customize which files are linked.
    Format: source_file:target_location:description

Cleanup Levels:
    1. Safe: Only removes symlinks, preserves backups and tools
    2. Restore: Removes symlinks and restores original files from backups
    3. Full: Complete cleanup including tool uninstallation

Debug Mode:
    Use --debug to get detailed information about symlink creation
    and troubleshooting information.

EOF
}

# Main script logic
main() {
    local command=""
    local custom_config=""

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
        install | i)
            command="install"
            shift
            ;;
        uninstall | u)
            command="uninstall"
            shift
            ;;
        list | l)
            command="list"
            shift
            ;;
        init)
            command="init"
            shift
            ;;
        help | h | --help)
            show_help
            exit 0
            ;;
        --config)
            custom_config="$2"
            shift 2
            ;;
        *)
            log_error "Unknown option: $1"
            show_help
            exit 1
            ;;
        esac
    done

    # Use custom config if specified
    if [[ -n "$custom_config" ]]; then
        CONFIG_FILE="$custom_config"
    fi

    # Change to script directory
    cd "$SCRIPT_DIR"

    # Detect OS
    local os=$(detect_os)
    log_info "Detected OS: $os"

    # Execute command
    case $command in
    install)
        install_dotfiles
        ;;
    uninstall)
        uninstall_dotfiles
        ;;
    list)
        list_dotfiles
        ;;
    init)
        if [[ ! -f "$CONFIG_FILE" ]]; then
            echo "$DEFAULT_CONFIG" >"$CONFIG_FILE"
            log_success "Created default configuration: $CONFIG_FILE"
        else
            log_warning "Configuration file already exists: $CONFIG_FILE"
        fi
        ;;
    "")
        log_error "No command specified"
        show_help
        exit 1
        ;;
    esac
}

# Run main function with all arguments
main "$@"

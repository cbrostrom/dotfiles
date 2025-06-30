#!/bin/bash

# Dotfiles Manager
# Supports macOS and WSL2 Ubuntu

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration file
CONFIG_FILE="$(dirname "$0")/dotfiles.conf"
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

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

    # Expand ~ to home directory
    target="${target/#\~/$HOME}"

    # Ensure target directory exists
    local target_dir=$(dirname "$target")
    if [[ ! -d "$target_dir" ]]; then
        log_info "Creating directory: $target_dir"
        mkdir -p "$target_dir"
    fi

    # Create backup if target exists
    create_backup "$target"

    # Create symlink using relative path for better cross-platform compatibility
    local relative_source=$(realpath --relative-to="$target_dir" "$SCRIPT_DIR/$source")
    if ln -sf "$relative_source" "$target"; then
        log_success "Linked $source -> $target ($description)"
    else
        log_error "Failed to link $source -> $target"
        return 1
    fi
}

install_dotfiles() {
    log_info "Installing dotfiles..."

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

        # Trim whitespace
        source=$(echo "$source" | xargs)
        target=$(echo "$target" | xargs)
        description=$(echo "$description" | xargs)

        if [[ -f "$SCRIPT_DIR/$source" ]]; then
            if create_symlink "$source" "$target" "$description"; then
                ((count++))
            else
                ((errors++))
            fi
        else
            log_warning "Source file not found: $SCRIPT_DIR/$source"
            ((errors++))
        fi
    done <"$CONFIG_FILE"

    if [[ $errors -eq 0 ]]; then
        log_success "Successfully linked $count dotfiles"
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
    uninstall, u   Remove all symlinks
    list, l        Show status of all dotfiles
    init           Initialize configuration file
    help, h        Show this help message

Options:
    --config FILE  Use custom configuration file (default: dotfiles.conf)

Examples:
    $(basename "$0") install
    $(basename "$0") list
    $(basename "$0") --config my-config.conf install

Configuration:
    Edit $CONFIG_FILE to customize which files are linked.
    Format: source_file:target_location:description

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

#!/bin/bash

# Dotfiles Installer
# Adds dotfiles.sh to PATH for macOS and WSL2 Ubuntu

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT_NAME="scripts/main.sh"
VERSION_SCRIPT_NAME="scripts/version.sh"
ALIAS_NAME="dotfiles"
VERSION_ALIAS_NAME="dotfiles-version"

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

detect_shell() {
    local shell_name=$(basename "$SHELL")
    echo "$shell_name"
}

get_shell_rc() {
    local shell_name="$1"
    case "$shell_name" in
    zsh)
        echo "$HOME/.zshrc"
        ;;
    bash)
        if [[ -f "$HOME/.bashrc" ]]; then
            echo "$HOME/.bashrc"
        elif [[ -f "$HOME/.bash_profile" ]]; then
            echo "$HOME/.bash_profile"
        else
            echo "$HOME/.bashrc"
        fi
        ;;
    *)
        echo "$HOME/.bashrc"
        ;;
    esac
}

install_to_path() {
    local shell_name=$(detect_shell)
    local shell_rc=$(get_shell_rc "$shell_name")

    log_info "Detected shell: $shell_name"
    log_info "Using RC file: $shell_rc"

    # Make the scripts executable
    if [[ ! -x "$SCRIPT_DIR/$SCRIPT_NAME" ]]; then
        log_info "Making dotfiles script executable..."
        chmod +x "$SCRIPT_DIR/$SCRIPT_NAME"
    fi

    if [[ ! -x "$SCRIPT_DIR/$VERSION_SCRIPT_NAME" ]]; then
        log_info "Making version script executable..."
        chmod +x "$SCRIPT_DIR/$VERSION_SCRIPT_NAME"
    fi

    # Create alias lines
    local dotfiles_alias="alias $ALIAS_NAME='../../dotfiles/$SCRIPT_NAME'"
    local version_alias="alias $VERSION_ALIAS_NAME='../../dotfiles/$VERSION_SCRIPT_NAME'"

    # Check if aliases already exist
    local dotfiles_exists=false
    local version_exists=false

    if grep -q "alias $ALIAS_NAME=" "$shell_rc" 2>/dev/null; then
        dotfiles_exists=true
    fi

    if grep -q "alias $VERSION_ALIAS_NAME=" "$shell_rc" 2>/dev/null; then
        version_exists=true
    fi

    if [[ "$dotfiles_exists" == "true" ]] || [[ "$version_exists" == "true" ]]; then
        log_warning "Some aliases already exist in $shell_rc"
        log_info "Updating existing aliases..."

        # Update existing aliases
        if [[ "$OSTYPE" == "darwin"* ]]; then
            # macOS sed
            if [[ "$dotfiles_exists" == "true" ]]; then
                sed -i '' "s|alias $ALIAS_NAME=.*|$dotfiles_alias|" "$shell_rc"
            fi
            if [[ "$version_exists" == "true" ]]; then
                sed -i '' "s|alias $VERSION_ALIAS_NAME=.*|$version_alias|" "$shell_rc"
            fi
        else
            # Linux sed
            if [[ "$dotfiles_exists" == "true" ]]; then
                sed -i "s|alias $ALIAS_NAME=.*|$dotfiles_alias|" "$shell_rc"
            fi
            if [[ "$version_exists" == "true" ]]; then
                sed -i "s|alias $VERSION_ALIAS_NAME=.*|$version_alias|" "$shell_rc"
            fi
        fi
    fi

    # Add new aliases if they don't exist
    if [[ "$dotfiles_exists" == "false" ]]; then
        log_info "Adding dotfiles alias to $shell_rc..."
        echo "" >>"$shell_rc"
        echo "# Dotfiles manager aliases" >>"$shell_rc"
        echo "$dotfiles_alias" >>"$shell_rc"
    fi

    if [[ "$version_exists" == "false" ]]; then
        log_info "Adding version manager alias to $shell_rc..."
        echo "$version_alias" >>"$shell_rc"
    fi

    log_success "Added aliases '$ALIAS_NAME' and '$VERSION_ALIAS_NAME' to $shell_rc"
    log_info "You can now use 'dotfiles' and 'dotfiles-version' commands from anywhere"
    log_info "Restart your shell or run 'source $shell_rc' to activate"
}

uninstall_from_path() {
    local shell_name=$(detect_shell)
    local shell_rc=$(get_shell_rc "$shell_name")

    log_info "Removing aliases from $shell_rc..."

    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS sed - remove the alias lines and the comments above them
        sed -i '' "/# Dotfiles manager aliases/,+2d" "$shell_rc"
    else
        # Linux sed
        sed -i "/# Dotfiles manager aliases/,+2d" "$shell_rc"
    fi

    log_success "Removed dotfiles and version manager aliases from $shell_rc"
}

show_help() {
    cat <<EOF
Dotfiles Installer - Install dotfiles.sh to your PATH

Usage: $(basename "$0") [COMMAND]

Commands:
    install, i     Install dotfiles.sh to PATH (default)
    uninstall, u   Remove dotfiles.sh from PATH
    help, h        Show this help message

Examples:
    $(basename "$0") install
    $(basename "$0") uninstall

After installation, you can use:
    dotfiles install    # Install all dotfiles
    dotfiles list       # Show status
    dotfiles help       # Show help

EOF
}

main() {
    local command="install"

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
        help | h | --help)
            show_help
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            show_help
            exit 1
            ;;
        esac
    done

    # Check if script exists
    if [[ ! -f "$SCRIPT_DIR/$SCRIPT_NAME" ]]; then
        log_error "Script not found: $SCRIPT_DIR/$SCRIPT_NAME"
        exit 1
    fi

    # Execute command
    case $command in
    install)
        install_to_path
        ;;
    uninstall)
        uninstall_from_path
        ;;
    esac
}

main "$@"

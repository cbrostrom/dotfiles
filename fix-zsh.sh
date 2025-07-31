#!/usr/bin/env bash

# ZSH Prompt Fix Script
# Fixes common zsh prompt issues on Debian/Ubuntu systems

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

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to fix zsh prompt issues
fix_zsh_prompt() {
    log_info "Fixing zsh prompt issues..."
    
    # Check if zsh is installed
    if ! command_exists zsh; then
        log_error "zsh is not installed. Please install it first:"
        log_info "sudo apt update && sudo apt install -y zsh"
        return 1
    fi
    
    # Check if .zshrc exists
    if [[ ! -f "$HOME/.zshrc" ]]; then
        log_warning ".zshrc does not exist, creating it..."
        touch "$HOME/.zshrc"
    fi
    
    # Check if .zshrc is symlinked to our dotfiles
    if [[ -L "$HOME/.zshrc" ]]; then
        local link_target=$(readlink "$HOME/.zshrc")
        if [[ "$link_target" == *"dotfiles"* ]] || [[ "$link_target" == *"$(basename "$SCRIPT_DIR")"* ]]; then
            log_success "✓ .zshrc is properly symlinked to dotfiles"
        else
            log_warning ".zshrc is symlinked but not to our dotfiles: $link_target"
            log_info "Recreating symlink..."
            rm "$HOME/.zshrc"
            ln -sf "$SCRIPT_DIR/.zshrc" "$HOME/.zshrc"
        fi
    elif [[ -f "$HOME/.zshrc" ]]; then
        log_warning ".zshrc exists but is not a symlink"
        log_info "Creating backup and symlinking..."
        mv "$HOME/.zshrc" "$HOME/.zshrc.backup.$(date +%Y%m%d_%H%M%S)"
        ln -sf "$SCRIPT_DIR/.zshrc" "$HOME/.zshrc"
    fi
    
    # Ensure zsh is in /etc/shells
    local zsh_path=$(which zsh)
    if ! grep -q "$zsh_path" /etc/shells; then
        log_warning "zsh not in /etc/shells, adding it..."
        echo "$zsh_path" | sudo tee -a /etc/shells
    fi
    
    # Change default shell to zsh
    if [[ "$SHELL" != "$zsh_path" ]]; then
        log_info "Changing default shell to zsh..."
        chsh -s "$zsh_path"
        log_success "Default shell changed to zsh"
        log_warning "Please log out and log back in for changes to take effect"
    else
        log_success "✓ zsh is already the default shell"
    fi
    
    # Test zsh configuration
    log_info "Testing zsh configuration..."
    if zsh -c "echo 'zsh configuration test successful'" 2>/dev/null; then
        log_success "✓ zsh configuration is valid"
    else
        log_error "❌ zsh configuration has errors"
        log_info "Check the .zshrc file for syntax errors"
        return 1
    fi
    
    # Check if starship is installed (for prompt)
    if command_exists starship; then
        log_success "✓ starship is installed"
    else
        log_warning "starship is not installed"
        log_info "You can install it with: cargo install starship"
    fi
    
    # Check if .config/starship.toml exists
    if [[ -f "$HOME/.config/starship.toml" ]]; then
        log_success "✓ starship configuration exists"
    else
        log_warning "starship configuration missing"
        if [[ -f "$SCRIPT_DIR/.config/starship.toml" ]]; then
            log_info "Creating starship config symlink..."
            mkdir -p "$HOME/.config"
            ln -sf "$SCRIPT_DIR/.config/starship.toml" "$HOME/.config/starship.toml"
        fi
    fi
}

# Function to check current status
check_status() {
    log_info "Checking current zsh status..."
    
    echo
    log_info "=== ZSH Status ==="
    
    # Check zsh installation
    if command_exists zsh; then
        local zsh_version=$(zsh --version | head -1)
        log_success "✓ zsh installed: $zsh_version"
    else
        log_error "✗ zsh not installed"
    fi
    
    # Check default shell
    local current_shell=$(echo $SHELL)
    log_info "Current shell: $current_shell"
    
    # Check .zshrc
    if [[ -f "$HOME/.zshrc" ]]; then
        if [[ -L "$HOME/.zshrc" ]]; then
            local link_target=$(readlink "$HOME/.zshrc")
            log_success "✓ .zshrc is symlinked to: $link_target"
        else
            log_warning "⚠ .zshrc exists but is not a symlink"
        fi
    else
        log_error "✗ .zshrc does not exist"
    fi
    
    # Check starship
    if command_exists starship; then
        local starship_version=$(starship --version)
        log_success "✓ starship installed: $starship_version"
    else
        log_warning "⚠ starship not installed"
    fi
    
    # Check starship config
    if [[ -f "$HOME/.config/starship.toml" ]]; then
        log_success "✓ starship config exists"
    else
        log_warning "⚠ starship config missing"
    fi
    
    echo
}

# Main function
main() {
    log_info "=== ZSH Prompt Fix Script ==="
    
    case "${1:-fix}" in
        "fix")
            fix_zsh_prompt
            ;;
        "status")
            check_status
            ;;
        "help"|"-h"|"--help")
            echo "Usage: $0 [COMMAND]"
            echo ""
            echo "Commands:"
            echo "  fix     - Fix zsh prompt issues (default)"
            echo "  status  - Check current zsh status"
            echo "  help    - Show this help message"
            ;;
        *)
            log_error "Unknown command: $1"
            echo "Use '$0 help' for usage information"
            exit 1
            ;;
    esac
    
    log_success "Script completed successfully!"
}

# Run main function
main "$@" 
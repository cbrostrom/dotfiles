#!/bin/bash

# =============================================================================
# DIRENV FIX SCRIPT
# =============================================================================
# This script fixes direnv issues, especially on WSL where asdf needs reshimming

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
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

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to detect OS
detect_os() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        OS_NAME="macOS"
        IS_MACOS=true
        IS_LINUX=false
        IS_WSL=false
    elif [[ "$OSTYPE" == "linux-gnu"* ]] || [[ "$OSTYPE" == "linux"* ]]; then
        OS_NAME="Linux"
        IS_MACOS=false
        IS_LINUX=true
        # Check for WSL
        if grep -q Microsoft /proc/version 2>/dev/null; then
            OS_NAME="WSL2"
            IS_WSL=true
        else
            IS_WSL=false
        fi
    else
        OS_NAME="Unknown"
        IS_MACOS=false
        IS_LINUX=false
        IS_WSL=false
    fi
}

# Function to fix direnv
fix_direnv() {
    log_info "Fixing direnv issues..."
    
    # Detect OS
    detect_os
    log_info "Detected OS: $OS_NAME"
    
    # Check if asdf is installed
    if ! command_exists asdf; then
        log_error "asdf is not installed. Please install asdf first."
        log_info "Run: ./install.sh to install asdf and direnv"
        return 1
    fi
    
    # Source asdf
    if [[ -f "$HOME/.asdf/asdf.sh" ]]; then
        source "$HOME/.asdf/asdf.sh"
        log_success "asdf sourced"
    else
        log_error "asdf not found at $HOME/.asdf/asdf.sh"
        return 1
    fi
    
    # Check if direnv plugin is installed
    if ! asdf plugin list | grep -q "direnv"; then
        log_info "Installing direnv plugin..."
        asdf plugin add direnv
        asdf install direnv latest
        asdf global direnv latest
        log_success "direnv plugin installed"
    else
        log_success "✓ direnv plugin already installed"
    fi
    
    # Reshim asdf
    log_info "Reshimming asdf..."
    asdf reshim
    log_success "asdf reshimmed"
    
    # Check if direnv is now available
    if command_exists direnv; then
        log_success "✓ direnv is now available"
        
        # Test direnv
        log_info "Testing direnv..."
        if direnv --version >/dev/null 2>&1; then
            log_success "✓ direnv is working correctly"
        else
            log_warning "direnv installed but may have issues"
        fi
    else
        log_error "direnv is still not available after reshimming"
        log_info "Try restarting your terminal or running: source ~/.zshrc"
        return 1
    fi
    
    # WSL-specific fixes
    if $IS_WSL; then
        log_info "Applying WSL-specific fixes..."
        
        # Ensure PATH includes asdf shims
        if ! echo "$PATH" | grep -q ".asdf/shims"; then
            log_info "Adding asdf shims to PATH..."
            echo 'export PATH="$HOME/.asdf/shims:$PATH"' >> "$HOME/.zshrc"
            log_success "PATH updated in .zshrc"
        fi
        
        # Source the updated configuration
        log_info "Sourcing updated configuration..."
        source "$HOME/.zshrc"
    fi
    
    log_success "direnv fix complete!"
    log_info "If you still have issues, try:"
    log_info "  1. Restart your terminal"
    log_info "  2. Run: source ~/.zshrc"
    log_info "  3. Run: asdf reshim direnv"
}

# Function to show help
show_help() {
    echo "Direnv Fix Script"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --help, -h    Show this help message"
    echo "  --fix         Fix direnv issues (default)"
    echo ""
    echo "This script fixes direnv issues, especially on WSL where asdf needs reshimming."
    echo ""
    echo "Common issues this fixes:"
    echo "  - 'unknown command: direnv'"
    echo "  - 'Perhaps you have to reshim?'"
    echo "  - direnv not found in PATH"
    echo ""
}

# Main function
main() {
    local fix_mode=false
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --help|-h)
                show_help
                exit 0
                ;;
            --fix)
                fix_mode=true
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # Default to fix mode if no options provided
    if ! $fix_mode; then
        fix_mode=true
    fi
    
    if $fix_mode; then
        fix_direnv
    fi
}

# Run main function
main "$@" 
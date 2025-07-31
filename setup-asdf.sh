#!/bin/bash

# =============================================================================
# ASDF SETUP SCRIPT
# =============================================================================
# This script sets up asdf in the repo and installs all necessary tools

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

# Function to setup asdf in repo
setup_asdf_in_repo() {
    log_info "Setting up asdf in repo..."
    
    # Check if we're in the dotfiles directory
    if [[ ! -f "install.sh" ]]; then
        log_error "Please run this script from the dotfiles directory"
        exit 1
    fi
    
    # Create asdf directory in repo
    mkdir -p .config/asdf
    
    # Clone asdf if not already present
    if [[ ! -d ".config/asdf/.git" ]]; then
        log_info "Cloning asdf into repo..."
        git clone https://github.com/asdf-vm/asdf.git .config/asdf --branch v0.13.1
        log_success "asdf cloned into repo"
    else
        log_success "✓ asdf already present in repo"
    fi
    
    # Create symlink from home to repo
    log_info "Creating symlink from ~/.asdf to repo..."
    if [[ -L "$HOME/.asdf" ]]; then
        log_info "Removing existing symlink..."
        rm "$HOME/.asdf"
    elif [[ -d "$HOME/.asdf" ]]; then
        log_info "Backing up existing asdf directory..."
        mv "$HOME/.asdf" "$HOME/.asdf.backup.$(date +%Y%m%d_%H%M%S)"
    fi
    
    ln -sf "$(pwd)/.config/asdf" "$HOME/.asdf"
    log_success "Symlink created: ~/.asdf -> $(pwd)/.config/asdf"
}

# Function to install asdf plugins
install_asdf_plugins() {
    log_info "Installing asdf plugins..."
    
    # Source asdf
    source .config/asdf/asdf.sh
    
    # List of plugins to install
    local plugins=("nodejs" "python" "golang" "rust" "direnv")
    
    for plugin in "${plugins[@]}"; do
        if asdf plugin list | grep -q "$plugin"; then
            log_success "✓ $plugin plugin already installed"
        else
            log_info "Installing $plugin plugin..."
            asdf plugin add "$plugin"
            log_success "$plugin plugin installed"
        fi
    done
}

# Function to install tools
install_tools() {
    log_info "Installing tools via asdf..."
    
    # Source asdf
    source .config/asdf/asdf.sh
    
    # Install Node.js
    log_info "Installing Node.js..."
    asdf install nodejs 24.4.1
    asdf global nodejs 24.4.1
    log_success "Node.js installed"
    
    # Install Python
    log_info "Installing Python..."
    asdf install python 3.12.7
    asdf global python 3.12.7
    log_success "Python installed"
    
    # Install Go
    log_info "Installing Go..."
    asdf install golang 1.22.0
    asdf global golang 1.22.0
    log_success "Go installed"
    
    # Install Rust
    log_info "Installing Rust..."
    asdf install rust latest
    asdf global rust latest
    log_success "Rust installed"
    
    # Install direnv
    log_info "Installing direnv..."
    asdf install direnv latest
    asdf global direnv latest
    log_success "direnv installed"
    
    # Reshim all tools
    log_info "Reshimming all tools..."
    asdf reshim
    log_success "All tools reshimmed"
}

# Function to test installation
test_installation() {
    log_info "Testing installation..."
    
    # Source asdf
    source .config/asdf/asdf.sh
    
    # Test asdf
    if command_exists asdf; then
        log_success "✓ asdf is working"
    else
        log_error "asdf is not working"
        return 1
    fi
    
    # Test tools
    local tools=("node" "python" "go" "cargo" "direnv")
    for tool in "${tools[@]}"; do
        if command_exists "$tool"; then
            log_success "✓ $tool is working"
        else
            log_warning "⚠ $tool is not working"
        fi
    done
}

# Function to show help
show_help() {
    echo "ASDF Setup Script"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --help, -h    Show this help message"
    echo "  --setup        Setup asdf in repo (default)"
    echo "  --plugins      Install asdf plugins only"
    echo "  --tools        Install tools only"
    echo "  --test         Test installation only"
    echo "  --full         Full setup (setup + plugins + tools + test)"
    echo ""
    echo "This script sets up asdf in the repo and installs all necessary tools."
    echo ""
}

# Main function
main() {
    local setup_mode=false
    local plugins_mode=false
    local tools_mode=false
    local test_mode=false
    local full_mode=false
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --help|-h)
                show_help
                exit 0
                ;;
            --setup)
                setup_mode=true
                shift
                ;;
            --plugins)
                plugins_mode=true
                shift
                ;;
            --tools)
                tools_mode=true
                shift
                ;;
            --test)
                test_mode=true
                shift
                ;;
            --full)
                full_mode=true
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # Default to setup mode if no options provided
    if ! $setup_mode && ! $plugins_mode && ! $tools_mode && ! $test_mode && ! $full_mode; then
        setup_mode=true
    fi
    
    if $full_mode; then
        setup_asdf_in_repo
        install_asdf_plugins
        install_tools
        test_installation
    else
        if $setup_mode; then
            setup_asdf_in_repo
        fi
        
        if $plugins_mode; then
            install_asdf_plugins
        fi
        
        if $tools_mode; then
            install_tools
        fi
        
        if $test_mode; then
            test_installation
        fi
    fi
    
    log_success "ASDF setup complete!"
}

# Run main function
main "$@" 
#!/usr/bin/env bash

# Install Missing Tools Script
# Installs tools that are missing based on status.sh output

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

# Function to detect package manager
detect_package_manager() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        PACKAGE_MANAGER="brew"
    else
        if command_exists apt; then
            PACKAGE_MANAGER="apt"
        elif command_exists yum; then
            PACKAGE_MANAGER="yum"
        elif command_exists dnf; then
            PACKAGE_MANAGER="dnf"
        else
            PACKAGE_MANAGER="none"
        fi
    fi
}

# Function to install a package if not already installed
install_package() {
    local package="$1"
    local description="$2"
    
    if command_exists "$package"; then
        log_success "✓ $description already installed"
        return 0
    fi
    
    log_info "Installing $description..."
    
    case "$PACKAGE_MANAGER" in
        "apt")
            sudo apt update && sudo apt install -y "$package"
            ;;
        "yum")
            sudo yum install -y "$package"
            ;;
        "dnf")
            sudo dnf install -y "$package"
            ;;
        "brew")
            brew install "$package"
            ;;
        *)
            log_warning "No package manager found, skipping $description"
            return 1
            ;;
    esac
    
    log_success "Installed $description"
}

# Function to install missing dotfiles
install_missing_dotfiles() {
    log_info "Installing missing dotfiles..."
    
    # Check and install .gitconfig
    if [[ ! -f "$HOME/.gitconfig" ]]; then
        log_info "Creating .gitconfig symlink..."
        ln -sf "$SCRIPT_DIR/.gitconfig" "$HOME/.gitconfig"
        log_success "Created .gitconfig symlink"
    else
        log_success "✓ .gitconfig already exists"
    fi
    
    # Check and install .gitignore_global
    if [[ ! -f "$HOME/.gitignore_global" ]]; then
        log_info "Creating .gitignore_global symlink..."
        ln -sf "$SCRIPT_DIR/.gitignore_global" "$HOME/.gitignore_global"
        log_success "Created .gitignore_global symlink"
    else
        log_success "✓ .gitignore_global already exists"
    fi
    
    # Check and install lsd config
    if [[ ! -d "$HOME/.config/lsd" ]]; then
        log_info "Creating lsd config symlink..."
        mkdir -p "$HOME/.config"
        ln -sf "$SCRIPT_DIR/.config/lsd" "$HOME/.config/lsd"
        log_success "Created lsd config symlink"
    else
        log_success "✓ lsd config already exists"
    fi
}

# Function to install missing tools via package manager
install_missing_package_tools() {
    log_info "Installing missing tools via package manager..."
    
    local packages=("fzf" "fd-find" "ripgrep" "bat" "lsd" "zoxide" "bottom" "procs" "du-dust" "tealdeer" "git-delta" "lazygit")
    
    # Update package list first
    if [[ "$PACKAGE_MANAGER" == "apt" ]]; then
        log_info "Updating package list..."
        sudo apt update
    fi
    
    for package in "${packages[@]}"; do
        if ! command_exists "$package"; then
            log_info "Installing $package..."
            if install_package "$package" "$package" 2>/dev/null; then
                log_success "✓ $package installed via package manager"
            else
                log_warning "⚠ $package not available via package manager"
            fi
        else
            log_success "✓ $package already installed"
        fi
    done
}

# Function to install missing development tools
install_missing_dev_tools() {
    log_info "Installing missing development tools..."
    
    # Source asdf if available
    if [[ -f "$HOME/.asdf/asdf.sh" ]]; then
        source "$HOME/.asdf/asdf.sh"
    fi
    
    # Install Go if missing
    if ! command_exists go; then
        log_info "Installing Go via asdf..."
        if command_exists asdf; then
            asdf install golang latest
            asdf global golang latest
            log_success "Go installed"
        else
            log_warning "asdf not available, skipping Go installation"
        fi
    else
        log_success "✓ Go already installed"
    fi
    
    # Install Rust if missing
    if ! command_exists cargo; then
        log_info "Installing Rust via asdf..."
        if command_exists asdf; then
            asdf install rust latest
            asdf global rust latest
            log_success "Rust installed"
        else
            log_warning "asdf not available, skipping Rust installation"
        fi
    else
        log_success "✓ Rust already installed"
    fi
    
    # Install Python if missing
    if ! command_exists python3; then
        log_info "Installing Python via asdf..."
        if command_exists asdf; then
            asdf install python latest
            asdf global python latest
            log_success "Python installed"
        else
            log_warning "asdf not available, skipping Python installation"
        fi
    else
        log_success "✓ Python already installed"
    fi
}

# Function to install missing cargo tools
install_missing_cargo_tools() {
    log_info "Installing missing cargo tools..."
    
    # Source asdf if available
    if [[ -f "$HOME/.asdf/asdf.sh" ]]; then
        source "$HOME/.asdf/asdf.sh"
    fi
    
    local cargo_tools=(
        "starship"      # Prompt
        "lsd"          # ls replacement
        "bat"          # cat replacement
        "ripgrep"      # grep replacement
        "fd-find"      # find replacement
        "procs"        # ps replacement
        "bottom"       # top replacement
        "zoxide"       # cd replacement
        "du-dust"      # du replacement
        "tealdeer"     # tldr replacement
        "ripgrep-all"  # search in all files
        "git-delta"    # git diff enhancement
        "git-fuzzy"    # git fuzzy finder
        "lazygit"      # git TUI
        "sd"           # sed replacement
    )
    
    for tool in "${cargo_tools[@]}"; do
        if ! command_exists "$tool"; then
            log_info "Installing $tool via cargo..."
            if cargo install "$tool" 2>/dev/null; then
                log_success "$tool installed"
            else
                log_warning "Failed to install $tool via cargo"
            fi
        else
            log_success "✓ $tool already installed"
        fi
    done
}

# Function to install asdf if missing
install_asdf() {
    log_info "Installing asdf version manager..."
    
    if command_exists asdf; then
        log_success "✓ asdf already installed"
    else
        if [[ ! -d "$HOME/.asdf" ]]; then
            log_info "Installing asdf..."
            git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch v0.13.1
            
            # Add asdf to shell configuration
            if [[ -f "$HOME/.zshrc" ]]; then
                if ! grep -q "asdf.sh" "$HOME/.zshrc"; then
                    echo '' >> "$HOME/.zshrc"
                    echo '# asdf version manager' >> "$HOME/.zshrc"
                    echo '. "$HOME/.asdf/asdf.sh"' >> "$HOME/.zshrc"
                    echo '. "$HOME/.asdf/completions/asdf.bash"' >> "$HOME/.zshrc"
                fi
            fi
            
            log_success "asdf installed"
        fi
    fi
    
    # Source asdf for current session
    if [[ -f "$HOME/.asdf/asdf.sh" ]]; then
        source "$HOME/.asdf/asdf.sh"
    fi
    
    # Install essential plugins
    log_info "Installing asdf plugins..."
    
    # Check if plugins exist, if not add them
    if ! asdf plugin list | grep -q "nodejs"; then
        asdf plugin add nodejs
    fi
    
    if ! asdf plugin list | grep -q "python"; then
        asdf plugin add python
    fi
    
    if ! asdf plugin list | grep -q "golang"; then
        asdf plugin add golang
    fi
    
    if ! asdf plugin list | grep -q "rust"; then
        asdf plugin add rust
    fi
    
    if ! asdf plugin list | grep -q "direnv"; then
        asdf plugin add direnv
    fi
    
    log_success "asdf plugins installed"
}

# Main function
main() {
    log_info "=== Install Missing Tools Script ==="
    
    # Detect package manager
    detect_package_manager
    log_info "Package manager: $PACKAGE_MANAGER"
    
    log_info ""
    log_info "=== Installing Missing Dotfiles ==="
    install_missing_dotfiles
    
    log_info ""
    log_info "=== Installing asdf (if missing) ==="
    install_asdf
    
    log_info ""
    log_info "=== Installing Missing Development Tools ==="
    install_missing_dev_tools
    
    log_info ""
    log_info "=== Installing Missing Package Tools ==="
    install_missing_package_tools
    
    log_info ""
    log_info "=== Installing Missing Cargo Tools ==="
    install_missing_cargo_tools
    
    log_info ""
    log_success "=== Installation Complete! ==="
    log_info ""
    log_info "Run './status.sh' to check the status of all components"
    log_info "Run './fix-zsh.sh status' to check zsh-specific issues"
}

# Run main function
main "$@" 
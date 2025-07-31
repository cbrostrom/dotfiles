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
    
    # Rust tools that can be installed via cargo
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
        "git-delta"    # git diff enhancement
        "sd"           # sed replacement
    )
    
    # Non-Rust tools that need different installation methods
    local non_rust_tools=(
        "lazygit"      # git TUI
        "ripgrep-all"  # search in all files (package manager)
        "git-fuzzy"    # git fuzzy finder (git clone)
    )
    
    # Install Rust tools via cargo
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
    
    # Install non-Rust tools
    for tool in "${non_rust_tools[@]}"; do
        if ! command_exists "$tool"; then
            log_info "Installing $tool..."
            case "$tool" in
                "lazygit")
                    install_lazygit_missing
                    ;;
                "ripgrep-all")
                    install_ripgrep_all_missing
                    ;;
                "git-fuzzy")
                    install_git_fuzzy_missing
                    ;;
            esac
        else
            log_success "✓ $tool already installed"
        fi
    done
}

# Function to install lazygit (for install-missing.sh)
install_lazygit_missing() {
    log_info "Installing lazygit..."
    
    if $IS_MACOS; then
        if command_exists brew; then
            brew install lazygit
            log_success "lazygit installed via Homebrew"
        else
            log_error "Homebrew not found. Please install Homebrew first."
            return 1
        fi
    else
        # Try package manager first
        if command_exists apt; then
            sudo apt update && sudo apt install -y lazygit
            log_success "lazygit installed via apt"
        elif command_exists yum; then
            sudo yum install -y lazygit
            log_success "lazygit installed via yum"
        elif command_exists dnf; then
            sudo dnf install -y lazygit
            log_success "lazygit installed via dnf"
        elif command_exists pacman; then
            sudo pacman -S lazygit
            log_success "lazygit installed via pacman"
        else
            # Fallback to Go install
            if command_exists go; then
                go install github.com/jesseduffield/lazygit@latest
                log_success "lazygit installed via Go"
            else
                log_error "No package manager or Go found. Please install lazygit manually."
                return 1
            fi
        fi
    fi
}

# Function to install ripgrep-all (for install-missing.sh)
install_ripgrep_all_missing() {
    log_info "Installing ripgrep-all..."
    
    if $IS_MACOS; then
        if command_exists brew; then
            brew install ripgrep-all
            log_success "ripgrep-all installed via Homebrew"
        else
            log_error "Homebrew not found. Please install Homebrew first."
            return 1
        fi
    else
        # Try package manager first
        if command_exists apt; then
            sudo apt update && sudo apt install -y ripgrep-all
            log_success "ripgrep-all installed via apt"
        elif command_exists yum; then
            sudo yum install -y ripgrep-all
            log_success "ripgrep-all installed via yum"
        elif command_exists dnf; then
            sudo dnf install -y ripgrep-all
            log_success "ripgrep-all installed via dnf"
        elif command_exists pacman; then
            sudo pacman -S ripgrep-all
            log_success "ripgrep-all installed via pacman"
        else
            # Fallback to cargo install (correct name)
            if command_exists cargo; then
                cargo install ripgrep_all
                log_success "ripgrep-all installed via cargo"
            else
                log_error "No package manager or cargo found. Please install ripgrep-all manually."
                return 1
            fi
        fi
    fi
}

# Function to install git-fuzzy (for install-missing.sh)
install_git_fuzzy_missing() {
    log_info "Installing git-fuzzy..."
    
    local git_fuzzy_dir="$HOME/.git-fuzzy"
    
    # Remove existing installation if it exists
    if [[ -d "$git_fuzzy_dir" ]]; then
        log_info "Removing existing git-fuzzy installation..."
        rm -rf "$git_fuzzy_dir"
    fi
    
    # Clone and install git-fuzzy
    if git clone https://github.com/bigH/git-fuzzy.git "$git_fuzzy_dir" 2>/dev/null; then
        cd "$git_fuzzy_dir"
        if make install 2>/dev/null; then
            log_success "git-fuzzy installed successfully"
            
            # Add to PATH if not already there
            if ! grep -q "git-fuzzy/bin" "$HOME/.zshrc" 2>/dev/null; then
                echo 'export PATH="$HOME/.git-fuzzy/bin:$PATH"' >> "$HOME/.zshrc"
                log_info "Added git-fuzzy to PATH in .zshrc"
            fi
        else
            log_warning "Failed to build git-fuzzy, but repository cloned to $git_fuzzy_dir"
            log_info "You can manually build it by running: cd $git_fuzzy_dir && make install"
        fi
    else
        log_error "Failed to clone git-fuzzy repository"
        return 1
    fi
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
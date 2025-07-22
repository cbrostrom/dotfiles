#!/usr/bin/env bash
# Debian ZSH Setup Script
# Installs and configures zsh with all necessary dependencies for the dotfiles
# Cross-platform compatible setup for Debian/Ubuntu servers

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Logging functions
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# OS Detection
if [[ "$OSTYPE" == "darwin"* ]]; then
    IS_MACOS=true
    IS_LINUX=false
elif [[ "$OSTYPE" == "linux-gnu"* ]] || [[ "$OSTYPE" == "linux"* ]]; then
    IS_MACOS=false
    IS_LINUX=true
    # Check for WSL
    if grep -q Microsoft /proc/version 2>/dev/null; then
        IS_WSL=true
    else
        IS_WSL=false
    fi
else
    IS_MACOS=false
    IS_LINUX=false
    IS_WSL=false
fi

# Check if running on Debian/Ubuntu
if ! $IS_LINUX; then
    log_error "This script is designed for Debian/Ubuntu systems"
    exit 1
fi

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to install package if not present
install_package() {
    local package="$1"
    local description="$2"
    
    if ! dpkg -l | grep -q "^ii  $package "; then
        log_info "Installing $description ($package)..."
        sudo apt-get update
        sudo apt-get install -y "$package"
        log_success "Installed $description"
    else
        log_success "✓ $description already installed"
    fi
}

# Function to install packages from list
install_packages() {
    local packages=("$@")
    log_info "Installing required packages..."
    
    for package in "${packages[@]}"; do
        install_package "$package" "$package"
    done
}

# Function to setup zinit plugin manager
setup_zinit() {
    log_info "Setting up zinit plugin manager..."
    
    ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"
    
    if [[ ! -d "$ZINIT_HOME" ]]; then
        log_info "Installing zinit..."
        mkdir -p "$(dirname "$ZINIT_HOME")"
        git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
        log_success "zinit installed successfully"
    else
        log_success "✓ zinit already installed"
    fi
}

# Function to setup NVM
setup_nvm() {
    log_info "Setting up Node Version Manager (NVM)..."
    
    if [[ ! -d "$HOME/.nvm" ]]; then
        log_info "Installing NVM..."
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
        log_success "NVM installed successfully"
    else
        log_success "✓ NVM already installed"
    fi
    
    # Source NVM for current session
    export NVM_DIR="$HOME/.nvm"
    [[ -s "$NVM_DIR/nvm.sh" ]] && source "$NVM_DIR/nvm.sh"
    [[ -s "$NVM_DIR/bash_completion" ]] && source "$NVM_DIR/bash_completion"
}

# Function to install Node.js via NVM
install_node() {
    log_info "Installing Node.js via NVM..."
    
    # Source NVM
    export NVM_DIR="$HOME/.nvm"
    [[ -s "$NVM_DIR/nvm.sh" ]] && source "$NVM_DIR/nvm.sh"
    
    # Install latest LTS Node.js
    if ! command_exists node; then
        log_info "Installing Node.js LTS..."
        nvm install --lts
        nvm use --lts
        nvm alias default node
        log_success "Node.js LTS installed and set as default"
    else
        log_success "✓ Node.js already installed"
    fi
}

# Function to install pnpm
setup_pnpm() {
    log_info "Setting up pnpm..."
    
    if ! command_exists pnpm; then
        log_info "Installing pnpm..."
        npm install -g pnpm
        log_success "pnpm installed successfully"
    else
        log_success "✓ pnpm already installed"
    fi
}

# Function to setup Go
setup_go() {
    log_info "Setting up Go..."
    
    if ! command_exists go; then
        log_info "Installing Go..."
        # Install Go from official source for latest version
        GO_VERSION="1.21.0"
        GO_ARCH="linux-amd64"
        
        wget -q "https://go.dev/dl/go${GO_VERSION}.${GO_ARCH}.tar.gz" -O /tmp/go.tar.gz
        sudo rm -rf /usr/local/go
        sudo tar -C /usr/local -xzf /tmp/go.tar.gz
        rm /tmp/go.tar.gz
        
        # Add to PATH
        echo 'export PATH="/usr/local/go/bin:$PATH"' >> "$HOME/.bashrc"
        export PATH="/usr/local/go/bin:$PATH"
        
        log_success "Go installed successfully"
    else
        log_success "✓ Go already installed"
    fi
    
    # Setup GOPATH
    mkdir -p "$HOME/go/bin"
    mkdir -p "$HOME/go/src"
    mkdir -p "$HOME/go/pkg"
}

# Function to install Rust tools
install_rust_tools() {
    log_info "Installing Rust-based tools..."
    
    # Install Rust if not present
    if ! command_exists cargo; then
        log_info "Installing Rust..."
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
        source "$HOME/.cargo/env"
        log_success "Rust installed successfully"
    else
        log_success "✓ Rust already installed"
        source "$HOME/.cargo/env"
    fi
    
    # Install Rust-based tools
    local rust_tools=(
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
    
    for tool in "${rust_tools[@]}"; do
        if ! command_exists "$tool"; then
            log_info "Installing $tool..."
            cargo install "$tool"
            log_success "$tool installed"
        else
            log_success "✓ $tool already installed"
        fi
    done
}

# Function to setup fzf
setup_fzf() {
    log_info "Setting up fzf..."
    
    if ! command_exists fzf; then
        log_info "Installing fzf..."
        git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf
        ~/.fzf/install --all
        log_success "fzf installed successfully"
    else
        log_success "✓ fzf already installed"
    fi
}

# Function to setup direnv
setup_direnv() {
    log_info "Setting up direnv..."
    
    if ! command_exists direnv; then
        log_info "Installing direnv..."
        curl -sfL https://direnv.net/install.sh | bash
        log_success "direnv installed successfully"
    else
        log_success "✓ direnv already installed"
    fi
}

# Function to setup asdf
setup_asdf() {
    log_info "Setting up asdf version manager..."
    
    if [[ ! -d "$HOME/.asdf" ]]; then
        log_info "Installing asdf..."
        git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch v0.13.1
        log_success "asdf installed successfully"
    else
        log_success "✓ asdf already installed"
    fi
}

# Function to fix zsh configuration
fix_zsh_config() {
    log_info "Fixing zsh configuration..."
    
    # Create necessary directories
    mkdir -p "$HOME/.local/bin"
    mkdir -p "$HOME/.local/share"
    mkdir -p "$HOME/.config"
    
    # Fix terminal issues
    if [[ -n "$TERM" ]]; then
        # Check if terminal type is supported
        if ! infocmp "$TERM" >/dev/null 2>&1; then
            # Fallback to common terminal types
            if infocmp "xterm-256color" >/dev/null 2>&1; then
                export TERM="xterm-256color"
            elif infocmp "xterm" >/dev/null 2>&1; then
                export TERM="xterm"
            elif infocmp "linux" >/dev/null 2>&1; then
                export TERM="linux"
            fi
        fi
    fi
    
    # Fix backspace issue
    if [[ -f "$HOME/.inputrc" ]]; then
        log_info "Fixing inputrc for backspace..."
        echo "set input-meta on" >> "$HOME/.inputrc"
        echo "set output-meta on" >> "$HOME/.inputrc"
        echo "set convert-meta off" >> "$HOME/.inputrc"
        echo "set bell-style none" >> "$HOME/.inputrc"
        echo "set horizontal-scroll-mode on" >> "$HOME/.inputrc"
        echo "set meta-flag on" >> "$HOME/.inputrc"
        echo "set input-meta on" >> "$HOME/.inputrc"
        echo "set output-meta on" >> "$HOME/.inputrc"
        echo "set convert-meta off" >> "$HOME/.inputrc"
    fi
    
    log_success "zsh configuration fixed"
}

# Function to setup shell integration
setup_shell_integration() {
    log_info "Setting up shell integration..."
    
    # Add necessary exports to shell profile
    local profile_file="$HOME/.bashrc"
    
    # Add PATH exports
    if ! grep -q "export PATH.*local/bin" "$profile_file"; then
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$profile_file"
    fi
    
    # Add Go exports
    if ! grep -q "export GOPATH" "$profile_file"; then
        echo 'export GOPATH="$HOME/go"' >> "$profile_file"
        echo 'export PATH="$GOPATH/bin:$PATH"' >> "$profile_file"
    fi
    
    # Add pnpm exports
    if ! grep -q "export PNPM_HOME" "$profile_file"; then
        echo 'export PNPM_HOME="$HOME/.local/share/pnpm"' >> "$profile_file"
        echo 'export PATH="$PNPM_HOME:$PATH"' >> "$profile_file"
    fi
    
    # Add Rust exports
    if ! grep -q "source.*cargo/env" "$profile_file"; then
        echo 'source "$HOME/.cargo/env"' >> "$profile_file"
    fi
    
    # Add asdf exports
    if ! grep -q "source.*asdf/asdf.sh" "$profile_file"; then
        echo '. "$HOME/.asdf/asdf.sh"' >> "$profile_file"
        echo '. "$HOME/.asdf/completions/asdf.bash"' >> "$profile_file"
    fi
    
    # Add NVM exports
    if ! grep -q "export NVM_DIR" "$profile_file"; then
        echo 'export NVM_DIR="$HOME/.nvm"' >> "$profile_file"
        echo '[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"' >> "$profile_file"
        echo '[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"' >> "$profile_file"
    fi
    
    log_success "Shell integration configured"
}

# Function to change default shell to zsh
change_default_shell() {
    log_info "Changing default shell to zsh..."
    
    if [[ "$SHELL" != "/bin/zsh" ]]; then
        log_info "Setting zsh as default shell..."
        chsh -s /bin/zsh
        log_success "Default shell changed to zsh"
        log_warning "Please log out and log back in for changes to take effect"
    else
        log_success "✓ zsh is already the default shell"
    fi
}

# Main setup function
main_setup() {
    log_info "=== Debian ZSH Setup Script ==="
    log_info "This script will install and configure zsh with all necessary dependencies"
    log_info "Detected OS: $(uname -s) $(uname -r)"
    
    # Check if running as root
    if [[ $EUID -eq 0 ]]; then
        log_error "Please do not run this script as root"
        exit 1
    fi
    
    # Install basic packages
    local basic_packages=(
        "zsh"
        "git"
        "curl"
        "wget"
        "build-essential"
        "pkg-config"
        "libssl-dev"
        "libreadline-dev"
        "zlib1g-dev"
        "libbz2-dev"
        "libsqlite3-dev"
        "libncursesw5-dev"
        "xz-utils"
        "tk-dev"
        "libxml2-dev"
        "libxmlsec1-dev"
        "libffi-dev"
        "liblzma-dev"
        "python3"
        "python3-pip"
        "nodejs"
        "npm"
    )
    
    install_packages "${basic_packages[@]}"
    
    # Setup various tools
    setup_zinit
    setup_nvm
    install_node
    setup_pnpm
    setup_go
    install_rust_tools
    setup_fzf
    setup_direnv
    setup_asdf
    
    # Fix configuration issues
    fix_zsh_config
    setup_shell_integration
    
    # Change default shell
    change_default_shell
    
    log_success "=== Setup Complete! ==="
    log_info "Please log out and log back in for all changes to take effect"
    log_info "Then run: ./dotfiles.sh to install your dotfiles"
}

# Run setup
main_setup 
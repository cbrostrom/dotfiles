#!/bin/bash

# Tool Installation Script
# Run this manually when you want to install or update tools

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Cross-platform path detection
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Logging functions
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# OS detection
OS_TYPE="$(uname -s)"
IS_MACOS=false
IS_LINUX=false
IS_WSL=false

if [[ "$OS_TYPE" == "Darwin" ]]; then
    IS_MACOS=true
    log_info "Detected: macOS"
elif [[ "$OS_TYPE" == "Linux" ]]; then
    IS_LINUX=true
    if grep -q Microsoft /proc/version 2>/dev/null; then
        IS_WSL=true
        log_info "Detected: WSL"
    else
        log_info "Detected: Linux"
    fi
fi

echo "🔧 Installing/Updating Tools"
echo "============================"
echo

if $IS_MACOS; then
    # macOS - use Homebrew
    if command -v brew &>/dev/null; then
        log_info "Installing tools via Homebrew..."

        # Core tools that are available in Homebrew
        brew install lsd bat ripgrep fd fzf lazygit atuin direnv starship htop ncdu

        log_success "Homebrew tools installed successfully"

        # Note about unavailable packages
        log_warning "Some tools are not available in Homebrew and will be installed manually:"
        log_info "  - tealdeer (install via cargo: cargo install tealdeer)"
        log_info "  - procs (install via cargo: cargo install procs)"
        log_info "  - ripgrep-all (install via cargo: cargo install ripgrep-all)"
        log_info "  - git-delta (install via cargo: cargo install git-delta)"
        log_info "  - git-fuzzy (install via cargo: cargo install git-fuzzy)"
    else
        log_error "Homebrew not found. Please install Homebrew first."
        exit 1
    fi

    # Install tools that need manual installation
    log_info "Installing tools that require manual installation..."

    # Tealdeer (tldr alternative)
    if ! command -v tealdeer &>/dev/null; then
        log_info "Installing tealdeer..."
        cargo install tealdeer
    else
        log_info "tealdeer already installed"
    fi

    # Procs
    if ! command -v procs &>/dev/null; then
        log_info "Installing procs..."
        cargo install procs
    else
        log_info "procs already installed"
    fi

    # Ripgrep-all
    if ! command -v rga &>/dev/null; then
        log_info "Installing ripgrep-all..."
        cargo install ripgrep-all
    else
        log_info "ripgrep-all already installed"
    fi

    # Git-delta
    if ! command -v delta &>/dev/null; then
        log_info "Installing git-delta..."
        cargo install git-delta
    else
        log_info "git-delta already installed"
    fi

    # Git-fuzzy
    if ! command -v git-fuzzy &>/dev/null; then
        log_info "Installing git-fuzzy..."
        cargo install git-fuzzy
    else
        log_info "git-fuzzy already installed"
    fi

    # ASDF (check if it needs manual installation)
    if ! command -v asdf &>/dev/null; then
        log_info "Installing asdf..."
        if [[ ! -d "$HOME/.asdf" ]]; then
            git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch v0.13.1
        fi
    else
        log_info "asdf already installed"
    fi

    log_success "Manual tools installed successfully"
elif $IS_LINUX; then
    # Linux/WSL - use apt with fallbacks
    if command -v apt &>/dev/null; then
        log_info "Updating package list..."
        sudo apt update -qq

        log_info "Installing tools via APT..."

        # Install packages that are available in apt
        sudo apt install -y lsd bat ripgrep fd-find fzf tldr direnv htop ncdu

        log_success "APT tools installed successfully"

        # Note about unavailable packages
        log_warning "Some tools are not available in Ubuntu repos and will be installed manually:"
        log_info "  - lazygit (install via go or binary)"
        log_info "  - procs (install via cargo: cargo install procs)"
        log_info "  - ripgrep-all (install via cargo: cargo install ripgrep-all)"
        log_info "  - git-delta (install via cargo: cargo install git-delta)"
    else
        log_error "APT not found. Please install APT first."
        exit 1
    fi

    # Install tools that need manual installation
    log_info "Installing tools that require manual installation..."

    # LazyGit
    if ! command -v lazygit &>/dev/null; then
        log_info "Installing lazygit..."
        # Try Go installation first, fallback to binary
        if command -v go &>/dev/null; then
            log_info "Installing lazygit via Go..."
            go install github.com/jesseduffield/lazygit@latest
        else
            log_info "Installing lazygit via binary download..."
            LAZYGIT_VERSION=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | grep -Po '"tag_name": "v\K[^"]*')
            curl -Lo lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/latest/download/lazygit_${LAZYGIT_VERSION}_Linux_x86_64.tar.gz"
            tar xf lazygit.tar.gz lazygit
            sudo mv lazygit /usr/local/bin
            rm lazygit.tar.gz
        fi
    else
        log_info "lazygit already installed"
    fi

    # Atuin
    if ! command -v atuin &>/dev/null; then
        log_info "Installing atuin..."
        curl -sSf https://atuin.sh/install.sh | bash
    else
        log_info "atuin already installed"
    fi

    # Starship
    if ! command -v starship &>/dev/null; then
        log_info "Installing starship..."
        curl -sS https://starship.rs/install.sh | sh
    else
        log_info "starship already installed"
    fi

    log_success "Manual tools installed successfully"
fi

echo
log_success "Tool installation completed!"
log_info "Restart your shell or run: source ~/.zshrc"

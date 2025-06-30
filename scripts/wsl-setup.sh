#!/bin/bash

# WSL Setup Script - Complete from-scratch setup
# Run this before installing dotfiles

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

echo "🚀 WSL Dotfiles Setup - From Scratch"
echo "===================================="
echo

# Check if running in WSL
if ! grep -q Microsoft /proc/version 2>/dev/null; then
    log_error "This script is designed for WSL. You appear to be running on native Linux."
    exit 1
fi

log_success "Detected WSL environment"

# Step 1: Update system
log_info "Step 1: Updating system packages..."
sudo apt update && sudo apt upgrade -y
log_success "System updated"

# Step 2: Install essential packages
log_info "Step 2: Installing essential packages..."
sudo apt install -y \
    git \
    curl \
    wget \
    unzip \
    build-essential \
    python3 \
    python3-pip \
    nodejs \
    npm \
    zsh \
    ca-certificates \
    gnupg \
    lsb-release

log_success "Essential packages installed"

# Step 3: Install Python tools
log_info "Step 3: Installing Python tools..."
pip3 install --user pipx
pipx ensurepath

# Step 4: Install Rust (for modern tools)
log_info "Step 4: Installing Rust..."
if ! command -v rustup &>/dev/null; then
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    source ~/.cargo/env
    log_success "Rust installed"
else
    log_info "Rust already installed"
fi

# Step 5: Install Node.js (if not already installed)
log_info "Step 5: Installing Node.js..."
if ! command -v node &>/dev/null; then
    curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
    sudo apt install -y nodejs
    log_success "Node.js installed"
else
    log_info "Node.js already installed"
fi

# Step 6: Set zsh as default shell
log_info "Step 6: Setting zsh as default shell..."
if [[ "$SHELL" != "/bin/zsh" ]]; then
    chsh -s /bin/zsh
    log_success "Zsh set as default shell"
    log_warning "You'll need to restart your terminal for this to take effect"
else
    log_info "Zsh is already the default shell"
fi

# Step 7: Create necessary directories
log_info "Step 7: Creating necessary directories..."
mkdir -p ~/.local/bin
mkdir -p ~/.config
mkdir -p ~/.cache

# Step 8: Set up git (if not already configured)
log_info "Step 8: Setting up git..."
if ! git config --global user.name &>/dev/null; then
    log_warning "Git not configured. Please run:"
    log_info "  git config --global user.name 'Your Name'"
    log_info "  git config --global user.email 'your.email@example.com'"
fi

echo
log_success "WSL setup completed!"
echo
log_info "Next steps:"
log_info "1. Clone your dotfiles repository:"
log_info "   git clone <your-repo-url> ~/dotfiles"
log_info "2. Navigate to dotfiles: cd ~/dotfiles"
log_info "3. Install dotfiles: ./scripts/dotfiles.sh install"
log_info "4. Install tools: ./scripts/install-tools.sh"
log_info "5. Restart your terminal or run: exec zsh"
echo
log_warning "Note: You may need to restart your terminal for all changes to take effect"

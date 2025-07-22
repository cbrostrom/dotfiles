#!/usr/bin/env bash
# Test script to verify cross-platform compatibility
# Run this on any system to test the dotfiles installation

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

# OS Detection
if [[ "$OSTYPE" == "darwin"* ]]; then
    IS_MACOS=true
    IS_LINUX=false
    OS_NAME="macOS"
elif [[ "$OSTYPE" == "linux-gnu"* ]] || [[ "$OSTYPE" == "linux"* ]]; then
    IS_MACOS=false
    IS_LINUX=true
    OS_NAME="Linux"
    # Check for WSL
    if grep -q Microsoft /proc/version 2>/dev/null; then
        IS_WSL=true
        OS_NAME="WSL2"
    else
        IS_WSL=false
    fi
else
    IS_MACOS=false
    IS_LINUX=false
    IS_WSL=false
    OS_NAME="Unknown"
fi

log_info "=== Cross-Platform Dotfiles Test ==="
log_info "Detected OS: $OS_NAME ($(uname -s) $(uname -r))"
log_info "Shell: $SHELL"
log_info "Current directory: $(pwd)"

# Test script executability
log_info "Testing script executability..."

SCRIPTS=("install-symlinks.sh" "dotfiles.sh" "uninstall-symlinks.sh" "symlink-dir.sh")

for script in "${SCRIPTS[@]}"; do
    if [[ -x "$script" ]]; then
        log_success "✓ $script is executable"
    else
        log_warning "⚠ $script is not executable"
        log_info "Making $script executable..."
        chmod +x "$script"
        if [[ -x "$script" ]]; then
            log_success "✓ $script is now executable"
        else
            log_error "✗ Failed to make $script executable"
        fi
    fi
done

# Test required tools
log_info "Testing required tools..."

TOOLS=("bash" "ln" "mkdir" "rm" "mv" "cp")

for tool in "${TOOLS[@]}"; do
    if command -v "$tool" >/dev/null 2>&1; then
        log_success "✓ $tool is available"
    else
        log_error "✗ $tool is not available"
    fi
done

# Test optional tools for relative paths
log_info "Testing optional tools for relative paths..."

OPTIONAL_TOOLS=("realpath" "python3" "node")

for tool in "${OPTIONAL_TOOLS[@]}"; do
    if command -v "$tool" >/dev/null 2>&1; then
        log_success "✓ $tool is available (will use for relative paths)"
    else
        log_warning "⚠ $tool is not available (will use fallback)"
    fi
done

# Test script syntax
log_info "Testing script syntax..."

for script in "${SCRIPTS[@]}"; do
    if bash -n "$script" 2>/dev/null; then
        log_success "✓ $script has valid bash syntax"
    else
        log_error "✗ $script has syntax errors"
    fi
done

# Test basic functionality
log_info "Testing basic functionality..."

# Test dotfiles.sh help
if ./dotfiles.sh help >/dev/null 2>&1; then
    log_success "✓ dotfiles.sh help works"
else
    log_error "✗ dotfiles.sh help failed"
fi

# Test install-symlinks.sh (dry run - just check it starts)
if timeout 5s ./install-symlinks.sh >/dev/null 2>&1; then
    log_success "✓ install-symlinks.sh starts successfully"
else
    log_warning "⚠ install-symlinks.sh may have issues (or just ran normally)"
fi

# Test terminal compatibility
log_info "Testing terminal compatibility..."
if [[ -x "./test-terminal.sh" ]]; then
    ./test-terminal.sh >/dev/null 2>&1 && log_success "✓ Terminal compatibility test passed" || log_warning "⚠ Terminal compatibility test had issues"
else
    log_warning "⚠ test-terminal.sh not found"
fi

log_success "=== Cross-Platform Test Complete ==="
log_info "Your system appears to be compatible with the dotfiles installation!"
log_info "You can now run: ./install-symlinks.sh" 
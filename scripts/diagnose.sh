#!/bin/bash

# Dotfiles Diagnostic Script
# Helps troubleshoot issues with dotfiles installation

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
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG_FILE="$(dirname "$0")/dotfiles.conf"

echo "🔍 Dotfiles Diagnostic Tool"
echo "=========================="
echo

# Check if we're in the right directory
log_info "Checking current directory..."
if [[ "$(basename "$PWD")" == "dotfiles" ]]; then
    log_success "Running from dotfiles directory"
else
    log_warning "Not running from dotfiles directory"
    log_info "Current: $PWD"
    log_info "Expected: $(dirname "$SCRIPT_DIR")/dotfiles"
fi
echo

# Check OS
log_info "Detecting OS..."
if [[ "$OSTYPE" == "darwin"* ]]; then
    OS="macOS"
    log_success "Detected: macOS"
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    if grep -q Microsoft /proc/version 2>/dev/null; then
        OS="WSL"
        log_success "Detected: WSL (Windows Subsystem for Linux)"
    else
        OS="Linux"
        log_success "Detected: Linux"
    fi
else
    OS="Unknown"
    log_warning "Unknown OS: $OSTYPE"
fi
echo

# Check required tools
log_info "Checking required tools..."

# Python
if command -v python3 >/dev/null 2>&1; then
    log_success "Python3: $(python3 --version 2>&1 | head -1)"
elif command -v python >/dev/null 2>&1; then
    log_success "Python: $(python --version 2>&1 | head -1)"
else
    log_warning "Python not found (needed for symlink creation)"
fi

# Node.js
if command -v node >/dev/null 2>&1; then
    log_success "Node.js: $(node --version)"
else
    log_warning "Node.js not found (alternative symlink method)"
fi

# Git
if command -v git >/dev/null 2>&1; then
    log_success "Git: $(git --version)"
else
    log_error "Git not found"
fi

# Package managers
if [[ "$OS" == "macOS" ]]; then
    if command -v brew >/dev/null 2>&1; then
        log_success "Homebrew: $(brew --version | head -1)"
    else
        log_warning "Homebrew not found"
    fi
elif [[ "$OS" == "Linux" || "$OS" == "WSL" ]]; then
    if command -v apt >/dev/null 2>&1; then
        log_success "APT: Available"
    else
        log_warning "APT not found"
    fi
fi
echo

# Check config file
log_info "Checking configuration..."
if [[ -f "$CONFIG_FILE" ]]; then
    log_success "Config file found: $CONFIG_FILE"
    echo "  Contents:"
    while IFS=: read -r source target description; do
        if [[ -n "$source" && ! "$source" =~ ^[[:space:]]*# ]]; then
            echo "    $source -> $target ($description)"
        fi
    done <"$CONFIG_FILE"
else
    log_error "Config file not found: $CONFIG_FILE"
fi
echo

# Check source files
log_info "Checking source files..."
missing_files=0
while IFS=: read -r source target description; do
    if [[ -n "$source" && ! "$source" =~ ^[[:space:]]*# ]]; then
        if [[ -f "$SCRIPT_DIR/$source" ]]; then
            log_success "✓ $source"
        else
            log_error "✗ $source (missing)"
            ((missing_files++))
        fi
    fi
done <"$CONFIG_FILE"

if [[ $missing_files -eq 0 ]]; then
    log_success "All source files present"
else
    log_warning "$missing_files source file(s) missing"
fi
echo

# Check symlinks
log_info "Checking existing symlinks..."
broken_links=0
while IFS=: read -r source target description; do
    if [[ -n "$source" && ! "$source" =~ ^[[:space:]]*# ]]; then
        target="${target/#\~/$HOME}"
        if [[ -L "$target" ]]; then
            link_target=$(readlink "$target")
            if [[ -f "$target" ]]; then
                log_success "✓ $target -> $link_target"
            else
                log_error "✗ $target -> $link_target (broken)"
                ((broken_links++))
            fi
        elif [[ -f "$target" ]]; then
            log_warning "! $target (file, not symlink)"
        elif [[ -d "$target" ]]; then
            log_warning "! $target (directory, not symlink)"
        else
            log_info "- $target (not linked)"
        fi
    fi
done <"$CONFIG_FILE"

if [[ $broken_links -eq 0 ]]; then
    log_success "No broken symlinks found"
else
    log_warning "$broken_links broken symlink(s) found"
fi
echo

# Test symlink creation
log_info "Testing symlink creation capability..."
test_source="$SCRIPT_DIR/.test_symlink"
test_target="$HOME/.test_symlink"

# Create test file
echo "test" >"$test_source"

# Try to create symlink
if python3 -c "
import os
try:
    os.symlink('$test_source', '$test_target')
    print('SUCCESS')
except Exception as e:
    print('ERROR: ' + str(e))
    exit(1)
" 2>/dev/null; then
    log_success "Python3 symlink creation: OK"
    rm -f "$test_target"
elif node -e "
const fs = require('fs');
try {
    fs.symlinkSync('$test_source', '$test_target');
    console.log('SUCCESS');
} catch (e) {
    console.log('ERROR: ' + e.message);
    process.exit(1);
}
" 2>/dev/null; then
    log_success "Node.js symlink creation: OK"
    rm -f "$test_target"
elif ln -sf "$test_source" "$test_target" 2>/dev/null; then
    log_success "Traditional ln symlink creation: OK"
    rm -f "$test_target"
else
    log_error "All symlink creation methods failed"
fi

# Clean up test file
rm -f "$test_source"
echo

# Check permissions
log_info "Checking permissions..."
if [[ -r "$SCRIPT_DIR" ]]; then
    log_success "Script directory readable"
else
    log_error "Script directory not readable"
fi

if [[ -w "$HOME" ]]; then
    log_success "Home directory writable"
else
    log_error "Home directory not writable"
fi
echo

# Summary
echo "📊 Summary"
echo "=========="
if [[ $missing_files -eq 0 && $broken_links -eq 0 ]]; then
    log_success "All checks passed! Your dotfiles setup looks good."
else
    log_warning "Issues found:"
    [[ $missing_files -gt 0 ]] && log_warning "  - $missing_files missing source files"
    [[ $broken_links -gt 0 ]] && log_warning "  - $broken_links broken symlinks"
    echo
    log_info "Recommendations:"
    log_info "  1. Run: ./scripts/dotfiles.sh --debug install"
    log_info "  2. Check file permissions"
    log_info "  3. Ensure you're running from the dotfiles directory"
fi
echo

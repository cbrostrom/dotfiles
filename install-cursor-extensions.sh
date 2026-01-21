#!/usr/bin/env bash

# Install Cursor Extensions from dotfiles
# Reads extensions.json and installs all listed extensions

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Logging functions
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Get script directory
if [[ -n "$BASH_SOURCE" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
else
    SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
fi

EXTENSIONS_FILE="$SCRIPT_DIR/.config/cursor/extensions.json"

log_info "=== Cursor Extension Installer ==="
log_info "Extensions file: $EXTENSIONS_FILE"
echo ""

# Detect CLI command (cursor on macOS, code on Linux with Cursor)
CLI_CMD=""
if command -v cursor >/dev/null 2>&1; then
    CLI_CMD="cursor"
elif command -v code >/dev/null 2>&1; then
    # Check if this is actually Cursor (not VSCode)
    if code --version 2>&1 | grep -q "cursor"; then
        CLI_CMD="code"
    fi
fi

# Check if CLI is available
if [[ -z "$CLI_CMD" ]]; then
    log_error "Cursor CLI not found in PATH"
    log_info "Please ensure Cursor is installed and the CLI is available"
    echo ""
    log_info "Setup instructions:"
    log_info "  macOS: sudo ln -s /Applications/Cursor.app/Contents/Resources/app/bin/cursor /usr/local/bin/cursor"
    log_info "  Linux: Cursor should add 'code' to PATH automatically"
    log_info "         If not, add to ~/.bashrc or ~/.zshrc:"
    log_info "         export PATH=\"\$PATH:/path/to/cursor/bin\""
    exit 1
fi

log_info "Using CLI command: $CLI_CMD"
echo ""

# Check if extensions.json exists
if [[ ! -f "$EXTENSIONS_FILE" ]]; then
    log_error "extensions.json not found: $EXTENSIONS_FILE"
    exit 1
fi

# Check if jq is available
if ! command -v jq >/dev/null 2>&1; then
    log_error "jq is required but not installed"
    log_info "Install with: brew install jq (macOS) or sudo apt install jq (Linux)"
    exit 1
fi

# Parse extensions.json
log_info "Reading extensions from $EXTENSIONS_FILE..."
EXTENSIONS=$(jq -r '.[].identifier' "$EXTENSIONS_FILE")

if [[ -z "$EXTENSIONS" ]]; then
    log_error "No extensions found in $EXTENSIONS_FILE"
    exit 1
fi

# Count total extensions
TOTAL=$(echo "$EXTENSIONS" | wc -l | tr -d ' ')
log_info "Found $TOTAL extensions to install"
echo ""

# Get currently installed extensions
log_info "Checking currently installed extensions..."
INSTALLED_EXTENSIONS=$($CLI_CMD --list-extensions 2>/dev/null || echo "")

# Install extensions
INSTALLED_COUNT=0
SKIPPED_COUNT=0
FAILED_COUNT=0

while IFS= read -r extension; do
    [[ -z "$extension" ]] && continue
    
    # Check if already installed
    if echo "$INSTALLED_EXTENSIONS" | grep -qi "^${extension}$"; then
        log_success "✓ Already installed: $extension"
        ((SKIPPED_COUNT++))
        continue
    fi
    
    # Install extension
    log_info "Installing: $extension"
    if $CLI_CMD --install-extension "$extension" --force 2>&1 | grep -q "successfully installed\|already installed"; then
        log_success "✓ Installed: $extension"
        ((INSTALLED_COUNT++))
    else
        log_error "✗ Failed: $extension"
        ((FAILED_COUNT++))
    fi
    
    # Small delay to avoid rate limiting
    sleep 0.5
done <<< "$EXTENSIONS"

# Summary
echo ""
log_info "=== Installation Summary ==="
log_success "✓ Installed: $INSTALLED_COUNT"
log_info "⊙ Already installed: $SKIPPED_COUNT"
[[ $FAILED_COUNT -gt 0 ]] && log_error "✗ Failed: $FAILED_COUNT"
echo ""

if [[ $FAILED_COUNT -gt 0 ]]; then
    log_warning "Some extensions failed to install. They may be:"
    log_warning "  - Deprecated or removed from marketplace"
    log_warning "  - Renamed or moved to different identifier"
    log_warning "  - Platform-specific and not available on this system"
    echo ""
fi

log_success "Extension installation complete!"
log_info "Restart Cursor to activate all extensions"

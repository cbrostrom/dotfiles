#!/usr/bin/env bash

# Update Cursor Extensions List
# Scans installed extensions and updates extensions.json

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
if [[ -n "$BASH_SOURCE" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
else
    SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
fi

EXTENSIONS_FILE="$SCRIPT_DIR/.config/cursor/extensions.json"
CURSOR_INTERNAL_JSON="$HOME/.cursor/extensions/extensions.json"
EXTENSIONS_DIR="$HOME/.cursor/extensions"

log_info "=== Cursor Extensions List Updater ==="
echo ""

# IMPORTANT: We update our dotfiles version, NOT Cursor's internal file
log_info "Target file: $EXTENSIONS_FILE"
log_info "Reading from: $CURSOR_INTERNAL_JSON"
echo ""

# Check if extensions directory exists
if [[ ! -d "$EXTENSIONS_DIR" ]]; then
    log_error "Extensions directory not found: $EXTENSIONS_DIR"
    exit 1
fi

# Check if jq is available
if ! command -v jq >/dev/null 2>&1; then
    log_error "jq is required but not installed"
    log_info "Install with: brew install jq (macOS) or sudo apt install jq (Linux)"
    exit 1
fi

# Backup existing extensions.json
if [[ -f "$EXTENSIONS_FILE" ]]; then
    BACKUP_FILE="${EXTENSIONS_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
    log_info "Creating backup: $BACKUP_FILE"
    cp "$EXTENSIONS_FILE" "$BACKUP_FILE"
fi

# Scan installed extensions using Cursor's internal metadata
log_info "Reading extension metadata from Cursor's internal database..."

# Try to read from Cursor's extensions.json if it exists and is valid
if [[ -f "$CURSOR_INTERNAL_JSON" ]] && jq empty "$CURSOR_INTERNAL_JSON" 2>/dev/null; then
    log_info "Using Cursor's extensions.json metadata"
    EXTENSIONS=$(jq -r '.[].identifier.id' "$CURSOR_INTERNAL_JSON" 2>/dev/null | sort -u)
else
    # Fallback: scan directory names
    log_warning "Cursor's extensions.json not found or invalid, scanning directories..."
    cd "$EXTENSIONS_DIR"
    EXTENSIONS=$(ls -1 | grep -v "^\." | grep -v "^extensions\.json" | sed 's/-[0-9].*//' | sort -u)
fi

if [[ -z "$EXTENSIONS" ]]; then
    log_error "No extensions found"
    exit 1
fi

# Count extensions
COUNT=$(echo "$EXTENSIONS" | wc -l | tr -d ' ')
log_info "Found $COUNT installed extensions"

# Generate simple JSON format (just identifier field, no metadata)
log_info "Generating extensions.json..."
echo "$EXTENSIONS" | jq -R -s 'split("\n") | map(select(length > 0)) | map({identifier: .})' > "$EXTENSIONS_FILE"

log_success "✓ extensions.json updated successfully"
log_info "File: $EXTENSIONS_FILE"
log_info "Extensions: $COUNT"
echo ""

# Show diff if backup exists
if [[ -f "$BACKUP_FILE" ]]; then
    # Count changes
    OLD_COUNT=$(jq '. | length' "$BACKUP_FILE")
    NEW_COUNT=$(jq '. | length' "$EXTENSIONS_FILE")
    DIFF=$((NEW_COUNT - OLD_COUNT))
    
    if [[ $DIFF -gt 0 ]]; then
        log_success "Added $DIFF new extension(s)"
    elif [[ $DIFF -lt 0 ]]; then
        log_warning "Removed ${DIFF#-} extension(s)"
    else
        log_info "No changes in extension count"
    fi
    
    # Show added extensions
    ADDED=$(jq -r --slurpfile old "$BACKUP_FILE" '.[] | select(.identifier as $id | $old[0] | map(.identifier) | index($id) | not) | .identifier' "$EXTENSIONS_FILE")
    if [[ -n "$ADDED" ]]; then
        echo ""
        log_info "Added extensions:"
        echo "$ADDED" | while read -r ext; do
            echo "  + $ext"
        done
    fi
    
    # Show removed extensions
    REMOVED=$(jq -r --slurpfile new "$EXTENSIONS_FILE" '.[] | select(.identifier as $id | $new[0] | map(.identifier) | index($id) | not) | .identifier' "$BACKUP_FILE")
    if [[ -n "$REMOVED" ]]; then
        echo ""
        log_warning "Removed extensions:"
        echo "$REMOVED" | while read -r ext; do
            echo "  - $ext"
        done
    fi
fi

echo ""
log_info "Next steps:"
log_info "1. Review changes: git diff .config/cursor/extensions.json"
log_info "2. Commit changes: git add .config/cursor/extensions.json && git commit -m 'chore: update Cursor extensions'"
log_info "3. Push to sync: git push"

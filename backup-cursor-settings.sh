#!/usr/bin/env bash

# Backup Cursor Settings Script
# Creates a timestamped backup of Cursor settings before making changes

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

# Cursor User directory
CURSOR_USER_DIR="$HOME/Library/Application Support/Cursor/User"

# Backup directory
BACKUP_DIR="$HOME/.cursor-backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_PATH="$BACKUP_DIR/backup_$TIMESTAMP"

# Check if Cursor User directory exists
if [[ ! -d "$CURSOR_USER_DIR" ]]; then
    log_error "Cursor User directory not found: $CURSOR_USER_DIR"
    exit 1
fi

log_info "Creating backup of Cursor settings..."
log_info "Backup location: $BACKUP_PATH"

# Create backup directory
mkdir -p "$BACKUP_PATH"

# Backup settings.json
if [[ -f "$CURSOR_USER_DIR/settings.json" ]]; then
    cp "$CURSOR_USER_DIR/settings.json" "$BACKUP_PATH/settings.json"
    log_success "Backed up settings.json"
else
    log_warning "settings.json not found"
fi

# Backup keybindings.json
if [[ -f "$CURSOR_USER_DIR/keybindings.json" ]]; then
    cp "$CURSOR_USER_DIR/keybindings.json" "$BACKUP_PATH/keybindings.json"
    log_success "Backed up keybindings.json"
else
    log_warning "keybindings.json not found"
fi

# Backup snippets directory
if [[ -d "$CURSOR_USER_DIR/snippets" ]]; then
    cp -r "$CURSOR_USER_DIR/snippets" "$BACKUP_PATH/snippets"
    log_success "Backed up snippets/"
else
    log_warning "snippets/ directory not found"
fi

log_success "Backup completed successfully!"
log_info "Backup saved to: $BACKUP_PATH"
log_info ""
log_info "To restore from this backup, run:"
log_info "  cp -r $BACKUP_PATH/* \"$CURSOR_USER_DIR/\""

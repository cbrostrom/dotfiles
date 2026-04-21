#!/usr/bin/env bash
# Test script to verify terminal compatibility

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

log_info "=== Terminal Compatibility Test ==="

# Test current terminal
log_info "Current TERM: $TERM"

# Test terminal type support
if infocmp "$TERM" >/dev/null 2>&1; then
    log_success "✓ Terminal type '$TERM' is supported"
else
    log_warning "⚠ Terminal type '$TERM' is not supported"
    
    # Test fallback terminals
    for term in "xterm-256color" "xterm" "linux"; do
        if infocmp "$term" >/dev/null 2>&1; then
            log_success "✓ Fallback terminal '$term' is available"
        else
            log_warning "⚠ Fallback terminal '$term' is not available"
        fi
    done
fi

# Test clear command
log_info "Testing clear command..."
if command -v clear >/dev/null 2>&1; then
    if clear 2>/dev/null; then
        log_success "✓ Clear command works"
    else
        log_warning "⚠ Clear command failed, but fallback available"
    fi
else
    log_warning "⚠ Clear command not found, but fallback available"
fi

# Test ANSI escape sequences
log_info "Testing ANSI escape sequences..."
printf '\033[2J\033[H' 2>/dev/null && log_success "✓ ANSI escape sequences work" || log_warning "⚠ ANSI escape sequences may not work"

log_success "=== Terminal Test Complete ===" 
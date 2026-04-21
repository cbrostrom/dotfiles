#!/usr/bin/env bash
# Quick Debian Terminal Fix
# Fixes terminal and backspace issues immediately

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

log_info "=== Quick Debian Terminal Fix ==="

# Force terminal type
log_info "Setting terminal type to xterm-256color..."
export TERM="xterm-256color"

# Create proper .inputrc
log_info "Creating .inputrc for proper backspace handling..."
cat > "$HOME/.inputrc" << 'EOF'
# Fix backspace and meta key issues
set input-meta on
set output-meta on
set convert-meta off
set bell-style none
set horizontal-scroll-mode on
set meta-flag on
set input-meta on
set output-meta on
set convert-meta off
# Ensure backspace sends DEL
set input-meta on
set output-meta on
set convert-meta off
EOF

# Apply inputrc immediately
if command -v bind >/dev/null 2>&1; then
    log_info "Applying inputrc configuration..."
    bind -f "$HOME/.inputrc"
fi

# Add to shell profile for persistence
log_info "Adding terminal configuration to shell profile..."
if ! grep -q "export TERM.*xterm-256color" "$HOME/.bashrc"; then
    echo '# Force terminal type for Linux/Debian compatibility' >> "$HOME/.bashrc"
    echo 'export TERM="xterm-256color"' >> "$HOME/.bashrc"
fi

if ! grep -q "bind.*inputrc" "$HOME/.bashrc"; then
    echo '# Apply inputrc for proper backspace handling' >> "$HOME/.bashrc"
    echo 'bind -f ~/.inputrc 2>/dev/null || true' >> "$HOME/.bashrc"
fi

log_success "=== Terminal Fix Complete! ==="
log_info "Current terminal type: $TERM"
log_info "Backspace should now work correctly"
log_info "You may need to start a new shell session for all changes to take effect" 
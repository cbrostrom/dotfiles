#!/bin/bash

# WSL Terminal Fix Script
# Fixes common issues that cause WSL terminals to close automatically

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

echo "🔧 WSL Terminal Fix"
echo "==================="
echo

# Check if running in WSL
if ! grep -q Microsoft /proc/version 2>/dev/null; then
    log_error "This script is designed for WSL. You appear to be running on native Linux."
    exit 1
fi

log_success "Detected WSL environment"

echo
log_info "1. Creating WSL configuration..."
echo "--------------------------------"

# Create WSL configuration to prevent issues
sudo tee /etc/wsl.conf >/dev/null <<'EOF'
[automount]
enabled = true
root = /mnt/
options = "metadata,umask=22,fmask=11"
mountFsTab = false

[network]
generateHosts = true
generateResolvConf = true

[interop]
enabled = true
appendWindowsPath = false

[user]
default = $(whoami)

[boot]
systemd = true
command = service ssh start
EOF

log_success "WSL configuration created"

echo
log_info "2. Optimizing shell startup..."
echo "-------------------------------"

# Create a minimal test .zshrc to isolate issues
if [[ ! -f ~/.zshrc.minimal ]]; then
    cat >~/.zshrc.minimal <<'EOF'
# Minimal zsh configuration for testing
export PATH="$HOME/.local/bin:$PATH"
export HISTSIZE=1000
export HISTFILE=~/.zsh_history
export SAVEHIST=$HISTSIZE

# Basic prompt
PS1='%n@%m %~ %# '

# Basic aliases
alias ll='ls -la'
alias la='ls -la'
EOF
    log_success "Created minimal .zshrc for testing"
fi

echo
log_info "3. Creating Windows .wslconfig template..."
echo "--------------------------------------------"

cat <<'EOF'

📝 WINDOWS CONFIGURATION REQUIRED:

Create a file called .wslconfig in your Windows user profile:
(Usually C:\Users\YourUsername\.wslconfig)

Add this content:

[wsl2]
memory=4GB
processors=4
swap=2GB
localhostForwarding=true
nestedVirtualization=true

[experimental]
networkingMode=mirrored
dnsTunneling=true
autoMemoryReclaim=gradual

EOF

log_warning "You need to create .wslconfig in Windows manually"
log_info "Location: C:\\Users\\$(whoami)\\.wslconfig"

echo
log_info "4. Checking for problematic processes..."
echo "----------------------------------------"

# Kill any hanging processes
log_info "Checking for hanging processes..."
HANGING_PROCESSES=$(ps aux | grep -E "(D|Z)" | grep -v grep | awk '{print $2}' || true)

if [[ -n "$HANGING_PROCESSES" ]]; then
    log_warning "Found hanging processes: $HANGING_PROCESSES"
    log_info "Killing hanging processes..."
    echo "$HANGING_PROCESSES" | xargs -r kill -9
    log_success "Hanging processes killed"
else
    log_success "No hanging processes found"
fi

echo
log_info "5. Optimizing memory usage..."
echo "-------------------------------"

# Clear caches
log_info "Clearing package caches..."
sudo apt clean 2>/dev/null || log_warning "Could not clear apt cache"

# Clear shell history cache
log_info "Clearing shell caches..."
rm -rf ~/.cache/zsh 2>/dev/null || true
rm -rf ~/.cache/zinit 2>/dev/null || true

log_success "Caches cleared"

echo
log_info "6. Testing shell stability..."
echo "-------------------------------"

log_info "Testing minimal shell configuration..."
log_info "To test if the issue is with your shell config:"
log_info "1. Backup current config: mv ~/.zshrc ~/.zshrc.backup"
log_info "2. Use minimal config: cp ~/.zshrc.minimal ~/.zshrc"
log_info "3. Test if terminal stays open"
log_info "4. If stable, gradually add back features"

echo
log_info "7. Quick fixes to try..."
echo "--------------------------"

cat <<'EOF'

🚀 IMMEDIATE FIXES TO TRY:

1. **Restart WSL completely:**
   # In Windows PowerShell (as admin):
   wsl --shutdown
   # Then restart your terminal

2. **Test with minimal shell:**
   mv ~/.zshrc ~/.zshrc.backup
   cp ~/.zshrc.minimal ~/.zshrc
   # Test if terminal stays open

3. **Use bash temporarily:**
   chsh -s /bin/bash
   # Test if bash is more stable

4. **Check Windows Event Viewer:**
   # Look for WSL-related errors in Windows Event Viewer

5. **Update Windows Terminal:**
   # Make sure you're using the latest Windows Terminal

6. **Disable problematic features:**
   # Temporarily disable zinit, starship
   # Add them back one by one

EOF

echo
log_info "8. Creating diagnostic script..."
echo "--------------------------------"

# Make the diagnostic script executable
chmod +x scripts/wsl-diagnose.sh

log_success "Run this to diagnose issues: ./scripts/wsl-diagnose.sh"

echo
log_success "WSL terminal fix completed!"
log_info "Try the quick fixes above and run the diagnostic script if issues persist."

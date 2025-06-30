#!/bin/bash

# WSL Terminal Diagnostic Script
# Helps identify why WSL terminals close automatically

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

echo "🔍 WSL Terminal Diagnostic"
echo "=========================="
echo

# Check if running in WSL
if ! grep -q Microsoft /proc/version 2>/dev/null; then
    log_error "This script is designed for WSL. You appear to be running on native Linux."
    exit 1
fi

log_success "Detected WSL environment"

echo
log_info "1. Checking WSL configuration..."
echo "--------------------------------"

# Check WSL version
if command -v wsl.exe &>/dev/null; then
    log_info "WSL version:"
    wsl.exe --version 2>/dev/null || log_warning "Could not determine WSL version"
else
    log_warning "wsl.exe not found in PATH"
fi

# Check WSL distribution info
log_info "Distribution info:"
cat /etc/os-release | grep -E "(NAME|VERSION)" || log_warning "Could not read OS release info"

echo
log_info "2. Checking memory and resources..."
echo "-------------------------------------"

# Check available memory
log_info "Memory usage:"
free -h || log_warning "Could not check memory"

# Check disk space
log_info "Disk space:"
df -h / || log_warning "Could not check disk space"

# Check CPU load
log_info "CPU load:"
uptime || log_warning "Could not check CPU load"

echo
log_info "3. Checking shell configuration..."
echo "-----------------------------------"

# Check current shell
log_info "Current shell: $SHELL"

# Check if zsh is properly installed
if command -v zsh &>/dev/null; then
    log_success "zsh is installed"
    zsh --version | head -1
else
    log_error "zsh is not installed"
fi

# Check shell startup files
log_info "Shell startup files:"
for file in ~/.zshrc ~/.bashrc ~/.profile ~/.bash_profile; do
    if [[ -f "$file" ]]; then
        log_success "Found: $file"
    else
        log_warning "Missing: $file"
    fi
done

echo
log_info "4. Checking for problematic processes..."
echo "----------------------------------------"

# Check for processes that might cause issues
log_info "Checking for background processes:"
ps aux | grep -E "(zinit|starship)" | grep -v grep || log_info "No problematic processes found"

# Check for hanging processes
log_info "Checking for hanging processes:"
ps aux | grep -E "(D|Z)" | grep -v grep || log_info "No hanging processes found"

echo
log_info "5. Checking WSL-specific issues..."
echo "-----------------------------------"

# Check WSL configuration
log_info "WSL configuration:"
if [[ -f /etc/wsl.conf ]]; then
    log_success "Found /etc/wsl.conf"
    cat /etc/wsl.conf
else
    log_warning "No /etc/wsl.conf found"
fi

# Check for Windows Terminal issues
log_info "Checking Windows Terminal compatibility:"
if [[ -n "$WT_SESSION" ]]; then
    log_info "Running in Windows Terminal"
else
    log_info "Not running in Windows Terminal"
fi

echo
log_info "6. Common causes and solutions..."
echo "==================================="

cat <<'EOF'

🔍 COMMON CAUSES OF WSL TERMINAL CLOSING:

1. **Memory Issues**
   - WSL running out of memory
   - Solution: Increase WSL memory limit in .wslconfig

2. **Shell Configuration Problems**
   - Infinite loops in shell startup files
   - Hanging processes during shell initialization
   - Solution: Check ~/.zshrc for problematic commands

3. **WSL Configuration Issues**
   - Corrupted WSL installation
   - Solution: Restart WSL or reinstall distribution

4. **Windows Terminal Issues**
   - Compatibility problems with certain shells
   - Solution: Use different terminal or update Windows Terminal

5. **Resource Exhaustion**
   - Too many background processes
   - Disk space issues
   - Solution: Clean up processes and disk space

🛠️ QUICK FIXES TO TRY:

1. **Restart WSL:**
   wsl --shutdown
   # Then restart your terminal

2. **Check WSL memory:**
   # Create .wslconfig in Windows %USERPROFILE%
   [wsl2]
   memory=4GB
   processors=4

3. **Simplify shell startup:**
   # Temporarily rename ~/.zshrc to test
   mv ~/.zshrc ~/.zshrc.backup
   # Test if terminal stays open

4. **Use bash instead of zsh:**
   chsh -s /bin/bash
   # Test if bash is more stable

5. **Check for hanging processes:**
   ps aux | grep -E "(D|Z)"
   # Kill any hanging processes

EOF

echo
log_info "7. Recommended next steps..."
echo "-----------------------------"

log_info "1. Try restarting WSL: wsl --shutdown"
log_info "2. Test with minimal shell config"
log_info "3. Check Windows Event Viewer for WSL errors"
log_info "4. Update Windows Terminal if using it"
log_info "5. Consider increasing WSL memory limit"

echo
log_success "Diagnostic complete!"
log_info "Check the output above for potential issues."

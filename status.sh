#!/usr/bin/env bash

# Dotfiles Status Checker v1.0
# Shows the status of all dotfiles and installed tools

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Logging functions
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Get script directory (cross-platform)
if [[ -n "$BASH_SOURCE" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
else
    SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
fi

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check symlink status
check_symlink() {
    local source="$1"
    local target="$2"
    local description="$3"

    if [[ -L "$target" ]]; then
        local link_target=$(readlink "$target")
        if [[ "$link_target" == "$source" ]] || [[ "$link_target" == *"$(basename "$source")" ]]; then
            log_success "✓ $description: $target -> $source"
        else
            log_warning "⚠ $description: $target -> $link_target (should be $source)"
        fi
    elif [[ -f "$target" ]]; then
        log_warning "⚠ $description: $target exists but is not a symlink"
    else
        log_error "✗ $description: $target does not exist"
    fi
}

# Function to check tool installation
check_tool() {
    local tool="$1"
    local description="$2"
    
    if command_exists "$tool"; then
        local version=$($tool --version 2>/dev/null | head -1 || echo "installed")
        log_success "✓ $description: $version"
    else
        log_error "✗ $description: not installed"
    fi
}

# Function to check directory
check_directory() {
    local dir="$1"
    local description="$2"
    
    if [[ -d "$dir" ]]; then
        log_success "✓ $description: $dir"
    else
        log_error "✗ $description: $dir does not exist"
    fi
}

# Main status check
main_status() {
    log_info "=== Dotfiles Status Check v1.0 ==="
    log_info "Script directory: $SCRIPT_DIR"
    log_info "Home directory: $HOME"
    log_info "Current shell: $SHELL"
    log_info "OS: $(uname -s) $(uname -r)"
    
    echo
    log_info "=== Dotfiles Symlinks ==="
    
    # Basic dotfiles
    check_symlink "$SCRIPT_DIR/.zshrc" "$HOME/.zshrc" ".zshrc"
    check_symlink "$SCRIPT_DIR/.gitconfig" "$HOME/.gitconfig" ".gitconfig"
    check_symlink "$SCRIPT_DIR/.gitignore_global" "$HOME/.gitignore_global" ".gitignore_global"

    # Config directories
    check_symlink "$SCRIPT_DIR/.config/lsd" "$HOME/.config/lsd" "lsd config"
    check_symlink "$SCRIPT_DIR/.config/starship.toml" "$HOME/.config/starship.toml" "starship config"
    
    # Platform-specific configs
    if [[ "$OSTYPE" == "darwin"* ]]; then
        check_symlink "$SCRIPT_DIR/.config/ghostty" "$HOME/.config/ghostty" "ghostty config"
    fi

    # Windows Terminal (if on WSL)
    if grep -q Microsoft /proc/version 2>/dev/null; then
        WINDOWS_TERMINAL_PATHS=(
            "$APPDATA/Packages/Microsoft.WindowsTerminal_8wekyb3d8bbwe/LocalState"
            "/mnt/c/Users/$USER/AppData/Local/Packages/Microsoft.WindowsTerminal_8wekyb3d8bbwe/LocalState"
            "/mnt/c/Users/$USERNAME/AppData/Local/Packages/Microsoft.WindowsTerminal_8wekyb3d8bbwe/LocalState"
        )

        for WINDOWS_TERMINAL_DIR in "${WINDOWS_TERMINAL_PATHS[@]}"; do
            if [[ -d "$WINDOWS_TERMINAL_DIR" ]]; then
                check_symlink "$SCRIPT_DIR/.config/windows-terminal/settings.json" "$WINDOWS_TERMINAL_DIR/settings.json" "Windows Terminal config"
                break
            fi
        done
    fi
    
    echo
    log_info "=== Core Tools ==="
    
    check_tool "zsh" "zsh shell"
    check_tool "git" "git"
    check_tool "starship" "starship prompt"
    check_tool "lsd" "lsd (modern ls)"
    check_tool "bat" "bat (modern cat)"
    check_tool "ripgrep" "ripgrep (rg)"
    check_tool "fzf" "fzf (fuzzy finder)"
    check_tool "direnv" "direnv"
    
    echo
    log_info "=== Development Tools ==="
    
    check_tool "node" "Node.js (via fnm)"
    check_tool "npm" "npm"
    check_tool "go" "Go (via asdf)"
    check_tool "cargo" "Rust/Cargo (via asdf)"
    check_tool "fnm" "fnm (Fast Node Manager)"
    check_tool "asdf" "asdf version manager"
    check_tool "python" "Python (via asdf)"
    
    echo
    log_info "=== Additional Tools ==="
    
    check_tool "fd" "fd (find replacement)"
    check_tool "procs" "procs (ps replacement)"
    check_tool "bottom" "bottom (top replacement)"
    check_tool "zoxide" "zoxide (cd replacement)"
    check_tool "du-dust" "dust (du replacement)"
    check_tool "tealdeer" "tldr (help replacement)"
    check_tool "git-delta" "git-delta"
    check_tool "lazygit" "lazygit"
    
    echo
    log_info "=== Directories ==="
    
    # Check fnm directory (only if fnm is installed)
    if command_exists fnm; then
        if [[ -d "$HOME/.local/share/fnm" ]]; then
            check_directory "$HOME/.local/share/fnm" "fnm directory"
        else
            log_warning "⚠ fnm directory: not found"
        fi
    else
        log_warning "⚠ fnm directory: not checked (fnm not installed)"
    fi
    
    # Check asdf directory (only if asdf is installed)
    if command_exists asdf; then
        # Check if it's a git installation
        if [[ -d "$HOME/.asdf" ]]; then
            check_directory "$HOME/.asdf" "asdf directory (git installation)"
        else
            log_info "ℹ asdf directory: not present (installed via Homebrew)"
        fi
    else
        log_warning "⚠ asdf directory: not checked (asdf not installed)"
    fi
                
                # Check Rust/Cargo directory (only if Rust is installed)
                if command_exists cargo; then
                    check_directory "$HOME/.cargo" "Rust/Cargo directory"
                else
                    log_warning "⚠ Rust/Cargo directory: not checked (Rust not installed)"
                fi
                
                # Check fzf directory (only if fzf is installed from source)
                if [[ -d "$HOME/.fzf" ]]; then
                    check_directory "$HOME/.fzf" "fzf directory (source install)"
                else
                    log_info "ℹ fzf directory: not present (likely installed via package manager)"
                fi
                
                check_directory "$HOME/.local/share/zinit" "zinit directory"
    
    echo
    log_info "=== Shell Configuration ==="
    
    if [[ "$SHELL" == "/bin/zsh" ]]; then
        log_success "✓ Default shell is zsh"
    else
        log_warning "⚠ Default shell is $SHELL (recommended: zsh)"
    fi
    
    if [[ -f "$HOME/.inputrc" ]]; then
        log_success "✓ .inputrc exists (backspace fix)"
    else
        log_warning "⚠ .inputrc missing (backspace may not work properly)"
    fi
    
    if grep -q "export TERM.*xterm-256color" "$HOME/.bashrc" 2>/dev/null; then
        log_success "✓ Terminal type configured in .bashrc"
    else
        log_warning "⚠ Terminal type not configured in .bashrc"
    fi
    
    echo
    log_info "=== Summary ==="
    
    local total_checks=0
    local passed_checks=0
    
    # Count checks (this is a simplified count)
    total_checks=$((total_checks + 6))  # symlinks
    total_checks=$((total_checks + 8))  # core tools
    total_checks=$((total_checks + 5))  # dev tools
    total_checks=$((total_checks + 8))  # additional tools
    total_checks=$((total_checks + 5))  # directories
    total_checks=$((total_checks + 3))  # shell config
    
    log_info "Total checks: $total_checks"
    log_info "Run './install.sh' to install missing components"
    log_info "Run './uninstall.sh' to remove dotfiles"
}

# Run status check
main_status 
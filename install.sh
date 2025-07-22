#!/usr/bin/env bash

# Dotfiles Installer v1.0
# Complete cross-platform dotfiles setup for macOS, Linux, and WSL2
# Single command installation: ./install.sh

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

# Function to detect package manager
detect_package_manager() {
    if $IS_MACOS; then
        # Check for Homebrew
        if command_exists brew; then
            PACKAGE_MANAGER="brew"
        elif [[ -f "/opt/homebrew/bin/brew" ]]; then
            PACKAGE_MANAGER="/opt/homebrew/bin/brew"
        else
            PACKAGE_MANAGER="none"
        fi
    else
        # Linux package managers
        if command_exists apt; then
            PACKAGE_MANAGER="apt"
        elif command_exists yum; then
            PACKAGE_MANAGER="yum"
        elif command_exists dnf; then
            PACKAGE_MANAGER="dnf"
        else
            PACKAGE_MANAGER="none"
        fi
    fi
}

# Function to install package
install_package() {
    local package="$1"
    local description="$2"
    
    if ! command_exists "$package"; then
        log_info "Installing $description..."
        
        case "$PACKAGE_MANAGER" in
            "brew"|"/opt/homebrew/bin/brew")
                $PACKAGE_MANAGER install "$package"
                ;;
            "apt")
                sudo apt-get update
                sudo apt-get install -y "$package"
                ;;
            "yum")
                sudo yum install -y "$package"
                ;;
            "dnf")
                sudo dnf install -y "$package"
                ;;
            *)
                log_warning "No package manager found, skipping $description"
                return 1
                ;;
        esac
        
        log_success "Installed $description"
    else
        log_success "✓ $description already installed"
    fi
}

# Function to install basic packages
install_basic_packages() {
    log_info "Installing basic packages..."
    
    if $IS_MACOS; then
        # macOS packages
        local packages=("git" "curl" "wget" "zsh")
        for package in "${packages[@]}"; do
            install_package "$package" "$package"
        done
    else
        # Linux packages
        local packages=(
            "zsh" "git" "curl" "wget" "build-essential" "pkg-config"
            "libssl-dev" "libreadline-dev" "zlib1g-dev" "libbz2-dev"
            "libsqlite3-dev" "libncursesw5-dev" "xz-utils" "tk-dev"
            "libxml2-dev" "libxmlsec1-dev" "libffi-dev" "liblzma-dev"
            "python3" "python3-pip" "nodejs" "npm"
        )
        for package in "${packages[@]}"; do
            install_package "$package" "$package"
        done
    fi
}

# Function to setup zinit plugin manager
setup_zinit() {
    log_info "Setting up zinit plugin manager..."
    
    ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"
    
    if [[ ! -d "$ZINIT_HOME" ]]; then
        log_info "Installing zinit..."
        mkdir -p "$(dirname "$ZINIT_HOME")"
        git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
        log_success "zinit installed successfully"
    else
        log_success "✓ zinit already installed"
    fi
}

# Function to setup NVM
setup_nvm() {
    log_info "Setting up Node Version Manager (NVM)..."
    
    if [[ ! -d "$HOME/.nvm" ]]; then
        log_info "Installing NVM..."
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
        log_success "NVM installed successfully"
    else
        log_success "✓ NVM already installed"
    fi
    
    # Source NVM for current session
    export NVM_DIR="$HOME/.nvm"
    [[ -s "$NVM_DIR/nvm.sh" ]] && source "$NVM_DIR/nvm.sh"
    [[ -s "$NVM_DIR/bash_completion" ]] && source "$NVM_DIR/bash_completion"
}

# Function to install Node.js via NVM
install_node() {
    log_info "Installing Node.js via NVM..."
    
    # Source NVM
    export NVM_DIR="$HOME/.nvm"
    [[ -s "$NVM_DIR/nvm.sh" ]] && source "$NVM_DIR/nvm.sh"
    
    # Install latest LTS Node.js
    if ! command_exists node; then
        log_info "Installing Node.js LTS..."
        nvm install --lts
        nvm use --lts
        nvm alias default node
        log_success "Node.js LTS installed and set as default"
    else
        log_success "✓ Node.js already installed"
    fi
}

# Function to setup Go
setup_go() {
    log_info "Setting up Go..."
    
    if ! command_exists go; then
        if $IS_MACOS && command_exists brew; then
            log_info "Installing Go via Homebrew..."
            brew install go
        else
            log_info "Installing Go from official source..."
            GO_VERSION="1.21.0"
            GO_ARCH="linux-amd64"
            
            wget -q "https://go.dev/dl/go${GO_VERSION}.${GO_ARCH}.tar.gz" -O /tmp/go.tar.gz
            sudo rm -rf /usr/local/go
            sudo tar -C /usr/local -xzf /tmp/go.tar.gz
            rm /tmp/go.tar.gz
            
            # Add to PATH
            echo 'export PATH="/usr/local/go/bin:$PATH"' >> "$HOME/.bashrc"
            export PATH="/usr/local/go/bin:$PATH"
        fi
        
        log_success "Go installed successfully"
    else
        log_success "✓ Go already installed"
    fi
    
    # Setup GOPATH
    mkdir -p "$HOME/go/bin"
    mkdir -p "$HOME/go/src"
    mkdir -p "$HOME/go/pkg"
}

# Function to install Rust tools
install_rust_tools() {
    log_info "Installing Rust-based tools..."
    
    # Install Rust if not present
    if ! command_exists cargo; then
        log_info "Installing Rust..."
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
        source "$HOME/.cargo/env"
        log_success "Rust installed successfully"
    else
        log_success "✓ Rust already installed"
        source "$HOME/.cargo/env"
    fi
    
    # Install Rust-based tools
    local rust_tools=(
        "starship"      # Prompt
        "lsd"          # ls replacement
        "bat"          # cat replacement
        "ripgrep"      # grep replacement
        "fd-find"      # find replacement
        "procs"        # ps replacement
        "bottom"       # top replacement
        "zoxide"       # cd replacement
        "du-dust"      # du replacement
        "tealdeer"     # tldr replacement
        "ripgrep-all"  # search in all files
        "git-delta"    # git diff enhancement
        "git-fuzzy"    # git fuzzy finder
        "lazygit"      # git TUI
        "sd"           # sed replacement
    )
    
    for tool in "${rust_tools[@]}"; do
        if ! command_exists "$tool"; then
            log_info "Installing $tool..."
            cargo install "$tool"
            log_success "$tool installed"
        else
            log_success "✓ $tool already installed"
        fi
    done
}

# Function to setup fzf
setup_fzf() {
    log_info "Setting up fzf..."
    
    if ! command_exists fzf; then
        log_info "Installing fzf..."
        git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf
        ~/.fzf/install --all
        log_success "fzf installed successfully"
    else
        log_success "✓ fzf already installed"
    fi
}

# Function to setup direnv
setup_direnv() {
    log_info "Setting up direnv..."
    
    if ! command_exists direnv; then
        log_info "Installing direnv..."
        curl -sfL https://direnv.net/install.sh | bash
        log_success "direnv installed successfully"
    else
        log_success "✓ direnv already installed"
    fi
}

# Function to setup asdf
setup_asdf() {
    log_info "Setting up asdf version manager..."
    
    if [[ ! -d "$HOME/.asdf" ]]; then
        log_info "Installing asdf..."
        git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch v0.13.1
        log_success "asdf installed successfully"
    else
        log_success "✓ asdf already installed"
    fi
}

# Function to fix terminal configuration
fix_terminal_config() {
    log_info "Fixing terminal configuration..."
    
    # Create necessary directories
    mkdir -p "$HOME/.local/bin"
    mkdir -p "$HOME/.local/share"
    mkdir -p "$HOME/.config"
    
    # Force terminal type for Linux/Debian
    if $IS_LINUX; then
        log_info "Setting terminal type to xterm-256color for Linux..."
        export TERM="xterm-256color"
    fi
    
    # Fix backspace issue immediately
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
        bind -f "$HOME/.inputrc"
    fi
    
    log_success "Terminal configuration fixed"
}

# Function to setup shell integration
setup_shell_integration() {
    log_info "Setting up shell integration..."
    
    # Determine shell profile file
    local profile_file="$HOME/.bashrc"
    
    # Force terminal type for Linux/Debian
    if $IS_LINUX && ! grep -q "export TERM.*xterm-256color" "$profile_file"; then
        echo '# Force terminal type for Linux/Debian compatibility' >> "$profile_file"
        echo 'export TERM="xterm-256color"' >> "$profile_file"
    fi
    
    # Add PATH exports
    if ! grep -q "export PATH.*local/bin" "$profile_file"; then
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$profile_file"
    fi
    
    # Add Go exports
    if ! grep -q "export GOPATH" "$profile_file"; then
        echo 'export GOPATH="$HOME/go"' >> "$profile_file"
        echo 'export PATH="$GOPATH/bin:$PATH"' >> "$profile_file"
    fi
    
    # Add npm configuration (skip pnpm as per user preference)
    if ! grep -q "npm config" "$profile_file"; then
        echo '# npm configuration' >> "$profile_file"
        echo 'npm config set fund false' >> "$profile_file"
        echo 'npm config set audit false' >> "$profile_file"
    fi
    
    # Add Rust exports
    if ! grep -q "source.*cargo/env" "$profile_file"; then
        echo 'source "$HOME/.cargo/env"' >> "$profile_file"
    fi
    
    # Add asdf exports
    if ! grep -q "source.*asdf/asdf.sh" "$profile_file"; then
        echo '. "$HOME/.asdf/asdf.sh"' >> "$profile_file"
        echo '. "$HOME/.asdf/completions/asdf.bash"' >> "$profile_file"
    fi
    
    # Add NVM exports
    if ! grep -q "export NVM_DIR" "$profile_file"; then
        echo 'export NVM_DIR="$HOME/.nvm"' >> "$profile_file"
        echo '[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"' >> "$profile_file"
        echo '[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"' >> "$profile_file"
    fi
    
    # Add inputrc binding
    if ! grep -q "bind.*inputrc" "$profile_file"; then
        echo '# Apply inputrc for proper backspace handling' >> "$profile_file"
        echo 'bind -f ~/.inputrc 2>/dev/null || true' >> "$profile_file"
    fi
    
    log_success "Shell integration configured"
}

# Function to change default shell to zsh
change_default_shell() {
    log_info "Changing default shell to zsh..."
    
    if [[ "$SHELL" != "/bin/zsh" ]]; then
        log_info "Setting zsh as default shell..."
        chsh -s /bin/zsh
        log_success "Default shell changed to zsh"
        log_warning "Please log out and log back in for changes to take effect"
    else
        log_success "✓ zsh is already the default shell"
    fi
}

# Function to create symlink with backup
create_symlink() {
    local source="$1"
    local target="$2"
    local description="$3"

    if [[ ! -e "$source" ]]; then
        log_warning "Source not found, skipping: $source"
        return 0
    fi

    # Create target directory if it doesn't exist
    local target_dir="$(dirname "$target")"
    if [[ ! -d "$target_dir" ]]; then
        log_info "Creating directory: $target_dir"
        mkdir -p "$target_dir"
    fi

    # Handle existing target
    if [[ -L "$target" ]]; then
        log_info "Removing existing symlink: $target"
        rm "$target"
    elif [[ -e "$target" ]]; then
        local backup="$target.backup.$(date +%Y%m%d_%H%M%S)"
        log_warning "Backing up existing file: $target -> $backup"
        mv "$target" "$backup"
    fi

    # Create relative symlink (cross-platform)
    local rel_source
    if command -v realpath >/dev/null 2>&1; then
        rel_source=$(realpath --relative-to="$(dirname "$target")" "$source" 2>/dev/null || echo "$source")
    elif command -v python3 >/dev/null 2>&1; then
        # Fallback using Python for relative path calculation
        rel_source=$(python3 -c "import os.path; print(os.path.relpath('$source', os.path.dirname('$target')))" 2>/dev/null || echo "$source")
    elif command -v node >/dev/null 2>&1; then
        # Fallback using Node.js
        rel_source=$(node -e "const path = require('path'); console.log(path.relative(path.dirname('$target'), '$source'))" 2>/dev/null || echo "$source")
    else
        # Final fallback - use absolute path
        rel_source="$source"
        log_warning "Using absolute path for symlink (install realpath, python3, or node for relative paths)"
    fi

    # Create symlink
    log_info "Creating symlink: $description"
    ln -sf "$rel_source" "$target"
    log_success "Created symlink: $target -> $rel_source"
}

# Function to install dotfiles symlinks
install_dotfiles() {
    log_info "Installing dotfiles symlinks..."
    
    # Basic dotfiles
    create_symlink "$SCRIPT_DIR/.zshrc" "$HOME/.zshrc" ".zshrc"
    create_symlink "$SCRIPT_DIR/.gitconfig" "$HOME/.gitconfig" ".gitconfig"
    create_symlink "$SCRIPT_DIR/.gitignore_global" "$HOME/.gitignore_global" ".gitignore_global"

    # Config directories
    create_symlink "$SCRIPT_DIR/.config/lsd" "$HOME/.config/lsd" "lsd config"
    create_symlink "$SCRIPT_DIR/.config/starship.toml" "$HOME/.config/starship.toml" "starship config"
    
    # Platform-specific configs
    if $IS_MACOS; then
        create_symlink "$SCRIPT_DIR/.config/ghostty" "$HOME/.config/ghostty" "ghostty config"
    fi

    # Windows Terminal (if on Windows/WSL)
    if $IS_WSL; then
        # Try multiple possible Windows Terminal paths
        WINDOWS_TERMINAL_PATHS=(
            "$APPDATA/Packages/Microsoft.WindowsTerminal_8wekyb3d8bbwe/LocalState"
            "/mnt/c/Users/$USER/AppData/Local/Packages/Microsoft.WindowsTerminal_8wekyb3d8bbwe/LocalState"
            "/mnt/c/Users/$USERNAME/AppData/Local/Packages/Microsoft.WindowsTerminal_8wekyb3d8bbwe/LocalState"
        )

        WINDOWS_TERMINAL_FOUND=false
        for WINDOWS_TERMINAL_DIR in "${WINDOWS_TERMINAL_PATHS[@]}"; do
            if [[ -d "$WINDOWS_TERMINAL_DIR" ]]; then
                log_info "Found Windows Terminal directory: $WINDOWS_TERMINAL_DIR"

                # Create backup of existing settings if they exist
                if [[ -f "$WINDOWS_TERMINAL_DIR/settings.json" ]]; then
                    BACKUP_FILE="$WINDOWS_TERMINAL_DIR/settings.json.backup.$(date +%Y%m%d_%H%M%S)"
                    log_info "Creating backup of existing Windows Terminal settings: $BACKUP_FILE"
                    cp "$WINDOWS_TERMINAL_DIR/settings.json" "$BACKUP_FILE"
                fi

                create_symlink "$SCRIPT_DIR/.config/windows-terminal/settings.json" "$WINDOWS_TERMINAL_DIR/settings.json" "Windows Terminal config"
                WINDOWS_TERMINAL_FOUND=true
                break
            fi
        done

        if [[ "$WINDOWS_TERMINAL_FOUND" == "false" ]]; then
            log_warning "Windows Terminal directory not found, skipping Windows Terminal config"
        fi
    fi
}

# Function to show help
show_help() {
    cat <<'EOF'
Dotfiles Installer v1.0

Usage: ./install.sh [OPTIONS]

Options:
  --help, -h          Show this help message
  --skip-deps         Skip dependency installation (only install dotfiles)
  --skip-dotfiles     Skip dotfiles installation (only install dependencies)
  --dry-run           Show what would be installed without actually installing

Examples:
  ./install.sh                    # Full installation
  ./install.sh --skip-deps        # Only install dotfiles
  ./install.sh --skip-dotfiles    # Only install dependencies
  ./install.sh --dry-run          # Preview installation

This script will:
1. Detect your OS (macOS, Linux, WSL2)
2. Install all necessary dependencies
3. Setup development tools (Node.js, Go, Rust, etc.)
4. Install and configure zsh with plugins
5. Create symlinks for all dotfiles
6. Configure terminal and shell integration

Supported platforms:
- macOS (with Homebrew)
- Linux (Ubuntu/Debian, CentOS/RHEL)
- WSL2 (Windows Subsystem for Linux)

EOF
}

# Function to perform dry run
dry_run() {
    log_info "=== DRY RUN - Preview of installation ==="
    log_info "Detected OS: $OS_NAME ($(uname -s) $(uname -r))"
    log_info "Script directory: $SCRIPT_DIR"
    log_info "Home directory: $HOME"
    
    log_info ""
    log_info "Would install packages:"
    if $IS_MACOS; then
        echo "  - git, curl, wget, zsh (via Homebrew)"
    else
        echo "  - zsh, git, curl, wget, build-essential, python3, nodejs, npm (via apt/yum/dnf)"
    fi
    
    log_info ""
    log_info "Would setup tools:"
    echo "  - zinit (plugin manager)"
    echo "  - NVM (Node Version Manager)"
    echo "  - Go (programming language)"
    echo "  - Rust (programming language)"
    echo "  - fzf (fuzzy finder)"
    echo "  - direnv (environment switching)"
    echo "  - asdf (version manager)"
    echo "  - Rust tools (starship, lsd, bat, ripgrep, etc.)"
    
    log_info ""
    log_info "Would create symlinks:"
    echo "  - ~/.zshrc"
    echo "  - ~/.gitconfig"
    echo "  - ~/.gitignore_global"
    echo "  - ~/.config/lsd/"
    echo "  - ~/.config/starship.toml"
    if $IS_MACOS; then
        echo "  - ~/.config/ghostty/"
    fi
    if $IS_WSL; then
        echo "  - Windows Terminal settings.json"
    fi
    
    log_info ""
    log_info "Would configure:"
    echo "  - Terminal type (xterm-256color on Linux)"
    echo "  - Shell integration"
    echo "  - Default shell (zsh)"
    echo "  - Backspace handling"
    
    log_success "Dry run complete - no changes made"
}

# Main installation function
main_installation() {
    local skip_deps=false
    local skip_dotfiles=false
    local dry_run_mode=false
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --help|-h)
                show_help
                exit 0
                ;;
            --skip-deps)
                skip_deps=true
                shift
                ;;
            --skip-dotfiles)
                skip_dotfiles=true
                shift
                ;;
            --dry-run)
                dry_run_mode=true
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    if $dry_run_mode; then
        dry_run
        exit 0
    fi
    
    log_info "=== Dotfiles Installer v1.0 ==="
    log_info "Detected OS: $OS_NAME ($(uname -s) $(uname -r))"
    log_info "Script directory: $SCRIPT_DIR"
    
    # Check if running as root
    if [[ $EUID -eq 0 ]]; then
        log_error "Please do not run this script as root"
        exit 1
    fi
    
    # Detect package manager
    detect_package_manager
    log_info "Package manager: $PACKAGE_MANAGER"
    
    if ! $skip_deps; then
        log_info ""
        log_info "=== Installing Dependencies ==="
        install_basic_packages
        setup_zinit
        setup_nvm
        install_node
        setup_go
        install_rust_tools
        setup_fzf
        setup_direnv
        setup_asdf
        fix_terminal_config
        setup_shell_integration
        change_default_shell
    fi
    
    if ! $skip_dotfiles; then
        log_info ""
        log_info "=== Installing Dotfiles ==="
        install_dotfiles
    fi
    
    log_info ""
    log_success "=== Installation Complete! ==="
    log_info ""
    log_info "Next steps:"
    log_info "1. Log out and log back in (or restart your terminal)"
    log_info "2. Your new zsh setup will be active"
    log_info "3. Run 'starship --version' to verify the prompt is working"
    log_info "4. Run 'lsd --version' to verify the ls replacement is working"
    log_info ""
    log_info "If you encounter any issues:"
    log_info "- Check ~/.zshrc for any errors"
    log_info "- Run 'source ~/.zshrc' to reload configuration"
    log_info "- Check the logs above for any warnings or errors"
}

# Run installation
main_installation "$@" 
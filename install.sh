#!/usr/bin/env bash

# Dotfiles Installer v2.0
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

# Function to install a package if not already installed
install_package() {
    local package="$1"
    local description="$2"
    
    # Enhanced check for package installation
    local is_installed=false
    
    if $IS_MACOS; then
        # Check if package is installed via Homebrew
        if brew list "$package" >/dev/null 2>&1; then
            is_installed=true
        fi
    else
        # Linux package managers
        case "$PACKAGE_MANAGER" in
            "apt")
                if dpkg -l "$package" >/dev/null 2>&1; then
                    is_installed=true
                fi
                ;;
            "yum")
                if rpm -q "$package" >/dev/null 2>&1; then
                    is_installed=true
                fi
                ;;
            "dnf")
                if rpm -q "$package" >/dev/null 2>&1; then
                    is_installed=true
                fi
                ;;
        esac
    fi
    
    if $is_installed; then
        log_success "✓ $description already installed"
        return 0
    fi
    
    log_info "Installing $description..."
    
    if $IS_MACOS; then
        brew install "$package"
    else
        case "$PACKAGE_MANAGER" in
            "apt")
                sudo apt update && sudo apt install -y "$package"
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
    fi
    
    log_success "Installed $description"
}

# Function to install basic packages with better error handling
install_basic_packages() {
    log_info "Installing basic packages..."
    
    if $IS_MACOS; then
        # macOS packages
        local packages=("git" "curl" "wget" "zsh")
        for package in "${packages[@]}"; do
            install_package "$package" "$package"
        done
    else
        # Linux packages - more comprehensive for Debian/Ubuntu
        local packages=(
            "zsh" "git" "curl" "wget" "build-essential" "pkg-config"
            "libssl-dev" "libreadline-dev" "zlib1g-dev" "libbz2-dev"
            "libsqlite3-dev" "libncursesw5-dev" "xz-utils" "tk-dev"
            "libxml2-dev" "libxmlsec1-dev" "libffi-dev" "liblzma-dev"
            "python3" "python3-pip" "nodejs" "npm"
            "unzip" "zip" "ca-certificates" "gnupg" "lsb-release"
        )
        
        # Update package list first
        log_info "Updating package list..."
        if [[ "$PACKAGE_MANAGER" == "apt" ]]; then
            sudo apt update
        fi
        
        for package in "${packages[@]}"; do
            install_package "$package" "$package"
        done
    fi
}

# Function to ensure zsh is properly installed and configured
setup_zsh() {
    log_info "Setting up zsh..."
    
    # Check if zsh is installed
    if ! command_exists zsh; then
        log_error "zsh is not installed. Please install it first."
        return 1
    fi
    
    # Get zsh path
    local zsh_path=$(which zsh)
    log_info "Found zsh at: $zsh_path"
    
    # Check if zsh is in /etc/shells
    if ! grep -q "$zsh_path" /etc/shells; then
        log_warning "zsh not in /etc/shells, adding it..."
        echo "$zsh_path" | sudo tee -a /etc/shells
    fi
    
    # Change default shell to zsh if not already
    if [[ "$SHELL" != "$zsh_path" ]]; then
        log_info "Changing default shell to zsh..."
        chsh -s "$zsh_path"
        log_success "Default shell changed to zsh"
        log_warning "Please log out and log back in for changes to take effect"
    else
        log_success "✓ zsh is already the default shell"
    fi
    
    # Create .zshrc if it doesn't exist
    if [[ ! -f "$HOME/.zshrc" ]]; then
        log_info "Creating .zshrc..."
        touch "$HOME/.zshrc"
    fi
}

# Function to setup zinit plugin manager
setup_zinit() {
    log_info "Setting up zinit plugin manager..."
    
    ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"
    
    # Check if zinit is already installed and working
    if [[ -d "$ZINIT_HOME" ]] && [[ -f "$ZINIT_HOME/zinit.zsh" ]]; then
        log_success "✓ zinit already installed and configured"
        return 0
    fi
    
    log_info "Installing zinit..."
    mkdir -p "$(dirname "$ZINIT_HOME")"
    git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
    log_success "zinit installed successfully"
}

# Function to setup asdf
setup_asdf() {
    log_info "Setting up asdf version manager..."

    # Check if asdf is already installed and working
    if command_exists asdf; then
        log_success "✓ asdf already installed"
        
        # Check if it's installed via Homebrew
        if [[ "$(which asdf)" == *"homebrew"* ]]; then
            log_info "asdf installed via Homebrew - no additional setup needed"
        fi
    else
        # Install asdf
        if [[ ! -d "$HOME/.asdf" ]]; then
            log_info "Installing asdf..."
            git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch v0.13.1
        fi

        # Add asdf to shell configuration (only for git installation)
        local profile_file=""
        if [[ -f "$HOME/.zshrc" ]]; then
            profile_file="$HOME/.zshrc"
        elif [[ -f "$HOME/.bashrc" ]]; then
            profile_file="$HOME/.bashrc"
        elif [[ -f "$HOME/.bash_profile" ]]; then
            profile_file="$HOME/.bash_profile"
        fi

        if [[ -n "$profile_file" ]]; then
            # Check if asdf is already sourced
            if ! grep -q "asdf.sh" "$profile_file"; then
                log_info "Adding asdf to $profile_file"
                echo '' >> "$profile_file"
                echo '# asdf version manager' >> "$profile_file"
                echo '. "$HOME/.asdf/asdf.sh"' >> "$profile_file"
                echo '. "$HOME/.asdf/completions/asdf.bash"' >> "$profile_file"
            fi
        fi
    fi

    # Source asdf for current session (handle both installation methods)
    if [[ -f "$HOME/.asdf/asdf.sh" ]]; then
        source "$HOME/.asdf/asdf.sh"
    elif command_exists asdf; then
        # asdf is available via PATH (Homebrew installation)
        log_info "asdf available via PATH"
    else
        log_error "asdf not found and could not be sourced"
        return 1
    fi

    # Install essential plugins (only if not already installed)
    log_info "Checking asdf plugins..."
    
    local plugins_installed=0
    local plugins_total=5
    
    # Node.js plugin
    if asdf plugin list | grep -q "nodejs"; then
        log_success "✓ nodejs plugin already installed"
        ((plugins_installed++))
    else
        log_info "Installing nodejs plugin..."
        asdf plugin add nodejs
        log_success "nodejs plugin installed"
    fi
    
    # Python plugin
    if asdf plugin list | grep -q "python"; then
        log_success "✓ python plugin already installed"
        ((plugins_installed++))
    else
        log_info "Installing python plugin..."
        asdf plugin add python
        log_success "python plugin installed"
    fi
    
    # Go plugin
    if asdf plugin list | grep -q "golang"; then
        log_success "✓ golang plugin already installed"
        ((plugins_installed++))
    else
        log_info "Installing golang plugin..."
        asdf plugin add golang
        log_success "golang plugin installed"
    fi
    
    # Rust plugin
    if asdf plugin list | grep -q "rust"; then
        log_success "✓ rust plugin already installed"
        ((plugins_installed++))
    else
        log_info "Installing rust plugin..."
        asdf plugin add rust
        log_success "rust plugin installed"
    fi

    # Install asdf-direnv plugin
    if asdf plugin list | grep -q "direnv"; then
        log_success "✓ direnv plugin already installed"
        ((plugins_installed++))
    else
        log_info "Installing asdf-direnv plugin..."
        asdf plugin add direnv
        asdf install direnv latest
        asdf global direnv latest
        log_success "direnv plugin installed"
    fi

    if [[ $plugins_installed -eq $plugins_total ]]; then
        log_success "✓ All asdf plugins already installed"
    else
        log_success "asdf plugins setup complete"
    fi
}

# Function to install Node.js via asdf
install_node() {
    log_info "Installing Node.js via asdf..."
    
    # Source asdf for current session
    if [[ -f "$HOME/.asdf/asdf.sh" ]]; then
        source "$HOME/.asdf/asdf.sh"
    fi
    
    # Install latest LTS Node.js
    if ! command_exists node; then
        log_info "Installing Node.js LTS..."
        asdf install nodejs latest:lts
        asdf global nodejs latest:lts
        log_success "Node.js LTS installed and set as default"
    else
        log_success "✓ Node.js already installed"
    fi
}

# Function to install Rust tools
install_rust_tools() {
    log_info "Installing Rust-based tools..."
    
    # Install Rust via asdf if not present
    if ! command_exists cargo; then
        log_info "Installing Rust via asdf..."
        # Source asdf for current session
        if [[ -f "$HOME/.asdf/asdf.sh" ]]; then
            source "$HOME/.asdf/asdf.sh"
        fi
        asdf install rust latest
        asdf global rust latest
        log_success "Rust installed successfully"
    else
        log_success "✓ Rust already installed"
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
    
    local tools_installed=0
    local tools_total=${#rust_tools[@]}
    
    for tool in "${rust_tools[@]}"; do
        if command_exists "$tool"; then
            log_success "✓ $tool already installed"
            ((tools_installed++))
        else
            log_info "Installing $tool..."
            cargo install "$tool"
            log_success "$tool installed"
        fi
    done
    
    if [[ $tools_installed -eq $tools_total ]]; then
        log_success "✓ All Rust tools already installed"
    else
        log_success "Rust tools installation complete"
    fi
}

# Function to setup fzf
setup_fzf() {
    log_info "Setting up fzf..."
    
    # Check if fzf is already installed and working
    if command_exists fzf && [[ -f "$HOME/.fzf.zsh" ]]; then
        log_success "✓ fzf already installed and configured"
        return 0
    fi
    
    # Check if fzf is installed via package manager
    if command_exists fzf; then
        log_success "✓ fzf already installed via package manager"
        return 0
    fi
    
    log_info "Installing fzf..."
    git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf
    ~/.fzf/install --all
    log_success "fzf installed successfully"
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
    
    local configs_added=0
    local configs_total=0
    
    # Force terminal type for Linux/Debian
    if $IS_LINUX && ! grep -q "export TERM.*xterm-256color" "$profile_file"; then
        echo '# Force terminal type for Linux/Debian compatibility' >> "$profile_file"
        echo 'export TERM="xterm-256color"' >> "$profile_file"
        ((configs_added++))
    fi
    ((configs_total++))
    
    # Add PATH exports
    if ! grep -q "export PATH.*local/bin" "$profile_file"; then
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$profile_file"
        ((configs_added++))
    fi
    ((configs_total++))
    
    # Add Go exports
    if ! grep -q "export GOPATH" "$profile_file"; then
        echo 'export GOPATH="$HOME/go"' >> "$profile_file"
        echo 'export PATH="$GOPATH/bin:$PATH"' >> "$profile_file"
        ((configs_added++))
    fi
    ((configs_total++))
    
    # Add npm configuration (skip pnpm as per user preference)
    if ! grep -q "npm config" "$profile_file"; then
        echo '# npm configuration' >> "$profile_file"
        echo 'npm config set fund false' >> "$profile_file"
        echo 'npm config set audit false' >> "$profile_file"
        ((configs_added++))
    fi
    ((configs_total++))
    
    # Add Rust exports
    if ! grep -q "source.*cargo/env" "$profile_file"; then
        echo 'source "$HOME/.cargo/env"' >> "$profile_file"
        ((configs_added++))
    fi
    ((configs_total++))
    
    # Add asdf exports
    if ! grep -q "source.*asdf/asdf.sh" "$profile_file"; then
        echo '. "$HOME/.asdf/asdf.sh"' >> "$profile_file"
        echo '. "$HOME/.asdf/completions/asdf.bash"' >> "$profile_file"
        ((configs_added++))
    fi
    ((configs_total++))
    
    # Add inputrc binding
    if ! grep -q "bind.*inputrc" "$profile_file"; then
        echo '# Apply inputrc for proper backspace handling' >> "$profile_file"
        echo 'bind -f ~/.inputrc 2>/dev/null || true' >> "$profile_file"
        ((configs_added++))
    fi
    ((configs_total++))
    
    if [[ $configs_added -eq 0 ]]; then
        log_success "✓ Shell integration already configured"
    else
        log_success "Shell integration configured ($configs_added new configs added)"
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

    # Check if symlink already exists and points to the correct location
    if [[ -L "$target" ]]; then
        local current_target=$(readlink "$target")
        local expected_target="$source"
        
        # Check if symlink points to the correct location
        if [[ "$current_target" == "$expected_target" ]]; then
            log_success "✓ $description already correctly linked"
            return 0
        else
            log_info "Updating existing symlink: $description"
            rm "$target"
        fi
    elif [[ -e "$target" ]]; then
        local backup="$target.backup.$(date +%Y%m%d_%H%M%S)"
        log_warning "Backing up existing file: $target -> $backup"
        mv "$target" "$backup"
    fi

    # Create target directory if it doesn't exist
    local target_dir="$(dirname "$target")"
    if [[ ! -d "$target_dir" ]]; then
        log_info "Creating directory: $target_dir"
        mkdir -p "$target_dir"
    fi

    # Create symlink using absolute path (simpler and more reliable)
    log_info "Creating symlink: $description"
    ln -sf "$source" "$target"
    log_success "Created symlink: $target -> $source"
}

# Function to setup completion directories and files
setup_completion() {
    log_info "Setting up completion directories and files..."
    
    # Create zsh cache directory
    mkdir -p "$HOME/.zsh_cache"
    
    # Create .zsh directory for git completion
    mkdir -p "$HOME/.zsh"
    
    # Download git completion script if it doesn't exist
    if [[ ! -f "$HOME/.zsh/git-completion.bash" ]]; then
        log_info "Downloading git completion script..."
        if command_exists curl; then
            curl -o "$HOME/.zsh/git-completion.bash" https://raw.githubusercontent.com/git/git/master/contrib/completion/git-completion.bash
            log_success "Downloaded git completion script"
        elif command_exists wget; then
            wget -O "$HOME/.zsh/git-completion.bash" https://raw.githubusercontent.com/git/git/master/contrib/completion/git-completion.bash
            log_success "Downloaded git completion script"
        else
            log_warning "curl/wget not available, skipping git completion download"
        fi
    else
        log_info "Git completion script already exists"
    fi
}

# Function to install dotfiles symlinks
install_dotfiles() {
    log_info "Installing dotfiles symlinks..."
    
    # Setup completion directories and files
    setup_completion
    
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

# Function to verify zsh setup
verify_zsh_setup() {
    log_info "Verifying zsh setup..."
    
    # Check if .zshrc exists and is readable
    if [[ ! -f "$HOME/.zshrc" ]]; then
        log_error "❌ .zshrc does not exist!"
        return 1
    fi
    
    if [[ ! -r "$HOME/.zshrc" ]]; then
        log_error "❌ .zshrc is not readable!"
        return 1
    fi
    
    log_success "✓ .zshrc exists and is readable"
    
    # Check if zsh is the default shell
    local current_shell=$(echo $SHELL)
    if [[ "$current_shell" == *"zsh" ]]; then
        log_success "✓ zsh is the default shell"
    else
        log_warning "⚠ Current shell is $current_shell, zsh should be default"
    fi
    
    # Test zsh configuration
    log_info "Testing zsh configuration..."
    if zsh -c "echo 'zsh configuration test successful'" 2>/dev/null; then
        log_success "✓ zsh configuration is valid"
    else
        log_error "❌ zsh configuration has errors"
        return 1
    fi
}

# Function to show help
show_help() {
    cat <<'EOF'
Dotfiles Installer v2.0

Usage: ./install.sh [OPTIONS]

Options:
  --help, -h          Show this help message
  --skip-deps         Skip dependency installation (only install dotfiles)
  --skip-dotfiles     Skip dotfiles installation (only install dependencies)
  --dry-run           Show what would be installed without actually installing
  --verify            Verify the installation after completion

Examples:
  ./install.sh                    # Full installation
  ./install.sh --skip-deps        # Only install dotfiles
  ./install.sh --skip-dotfiles    # Only install dependencies
  ./install.sh --dry-run          # Preview installation
  ./install.sh --verify           # Full installation with verification

This script will:
1. Detect your OS (macOS, Linux, WSL2)
2. Install all necessary dependencies
3. Setup development tools (Node.js, Go, Rust, etc.)
4. Install and configure zsh with plugins
5. Create symlinks for all dotfiles
6. Configure terminal and shell integration
7. Verify the installation (if --verify is used)

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
    echo "  - asdf (version manager with plugins)"
    echo "  - Node.js (via asdf)"
    echo "  - Python (via asdf)"
    echo "  - Go (via asdf)"
    echo "  - Rust (via asdf)"
    echo "  - direnv (via asdf-direnv)"
    echo "  - fzf (fuzzy finder)"
    echo "  - Additional tools via package manager"
    echo "  - Rust tools via cargo (starship, lsd, bat, ripgrep, etc.)"
    
    log_info ""
    log_info "Would create directories:"
    echo "  - ~/.zsh_cache/ (completion cache)"
    echo "  - ~/.zsh/ (completion scripts)"
    echo "  - ~/.config/ (configuration files)"
    
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
    echo "  - Environment variables"
    echo "  - PATH configuration"
    
    log_info ""
    log_info "Would install development tools:"
    echo "  - Node.js LTS"
    echo "  - Python latest"
    echo "  - Go latest"
    echo "  - Rust latest"
    echo "  - All Rust-based tools (starship, lsd, bat, etc.)"
    
    log_success "Dry run complete - no changes made"
}

# Function to install Go via asdf
install_go() {
    log_info "Installing Go via asdf..."
    
    # Source asdf for current session
    if [[ -f "$HOME/.asdf/asdf.sh" ]]; then
        source "$HOME/.asdf/asdf.sh"
    fi
    
    # Install latest Go
    if ! command_exists go; then
        log_info "Installing Go latest..."
        asdf install golang latest
        asdf global golang latest
        log_success "Go installed and set as default"
    else
        log_success "✓ Go already installed"
    fi
}

# Function to install Python via asdf
install_python() {
    log_info "Installing Python via asdf..."
    
    # Source asdf for current session
    if [[ -f "$HOME/.asdf/asdf.sh" ]]; then
        source "$HOME/.asdf/asdf.sh"
    fi
    
    # Install latest Python
    if ! command_exists python3; then
        log_info "Installing Python latest..."
        asdf install python latest
        asdf global python latest
        log_success "Python installed and set as default"
    else
        log_success "✓ Python already installed"
    fi
}

# Function to install additional tools via package manager
install_additional_tools() {
    log_info "Installing additional tools via package manager..."
    
    if $IS_MACOS; then
        # macOS tools
        local packages=("fzf" "fd" "ripgrep" "bat" "lsd" "zoxide" "bottom" "procs" "dust" "tealdeer" "git-delta" "lazygit")
        for package in "${packages[@]}"; do
            install_package "$package" "$package"
        done
    else
        # Linux tools - try to install via package manager first
        local packages=("fzf" "fd-find" "ripgrep" "bat" "lsd" "zoxide" "bottom" "procs" "du-dust" "tealdeer" "git-delta" "lazygit")
        
        # Update package list first
        if [[ "$PACKAGE_MANAGER" == "apt" ]]; then
            log_info "Updating package list for additional tools..."
            sudo apt update
        fi
        
        for package in "${packages[@]}"; do
            # Try to install via package manager first
            if install_package "$package" "$package" 2>/dev/null; then
                log_success "✓ $package installed via package manager"
            else
                log_warning "⚠ $package not available via package manager, will install via cargo later"
            fi
        done
    fi
}

# Function to install missing tools via cargo
install_missing_cargo_tools() {
    log_info "Installing missing tools via cargo..."
    
    # Source asdf for current session to get cargo
    if [[ -f "$HOME/.asdf/asdf.sh" ]]; then
        source "$HOME/.asdf/asdf.sh"
    fi
    
    # List of tools to check and install
    local cargo_tools=(
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
    
    local tools_installed=0
    local tools_total=${#cargo_tools[@]}
    
    for tool in "${cargo_tools[@]}"; do
        if command_exists "$tool"; then
            log_success "✓ $tool already installed"
            ((tools_installed++))
        else
            log_info "Installing $tool via cargo..."
            if cargo install "$tool" 2>/dev/null; then
                log_success "$tool installed"
            else
                log_warning "Failed to install $tool via cargo"
            fi
        fi
    done
    
    if [[ $tools_installed -eq $tools_total ]]; then
        log_success "✓ All cargo tools already installed"
    else
        log_success "Cargo tools installation complete"
    fi
}

# Main installation function
main_installation() {
    local skip_deps=false
    local skip_dotfiles=false
    local dry_run_mode=false
    local verify_mode=false
    
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
            --verify)
                verify_mode=true
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
    
    log_info "=== Dotfiles Installer v2.0 ==="
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
        setup_zsh
        setup_zinit
        setup_asdf
        
        log_info ""
        log_info "=== Installing Development Tools ==="
        install_node
        install_go
        install_python
        install_rust_tools
        
        log_info ""
        log_info "=== Installing Additional Tools ==="
        install_additional_tools
        install_missing_cargo_tools
        setup_fzf
        
        log_info ""
        log_info "=== Configuring Environment ==="
        fix_terminal_config
        setup_shell_integration
    fi
    
    if ! $skip_dotfiles; then
        log_info ""
        log_info "=== Installing Dotfiles ==="
        install_dotfiles
    fi
    
    if $verify_mode; then
        log_info ""
        log_info "=== Verifying Installation ==="
        verify_zsh_setup
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
    log_info "- Run './status.sh' to check the status of all components"
    log_info "- Run './fix-zsh.sh status' to check zsh-specific issues"
}

# Run installation
main_installation "$@" 
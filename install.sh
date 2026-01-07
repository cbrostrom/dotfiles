#!/usr/bin/env bash

# Dotfiles Installer v3.0 (Simplified)
# Cross-platform dotfiles setup for macOS, Linux, and WSL2
# Removed: asdf, Rust tools (using package managers instead)
# Kept: fnm for Node.js

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

# =============================================================================
# LOCAL CONFIG MANAGEMENT
# =============================================================================

# Initialize .local-config if it doesn't exist
init_local_config() {
    local config_file="$SCRIPT_DIR/.local-config"
    local example_file="$SCRIPT_DIR/.local-config.example"
    
    if [[ ! -f "$config_file" ]]; then
        if [[ -f "$example_file" ]]; then
            log_info "Creating .local-config from example..."
            cp "$example_file" "$config_file"
            
            # Auto-detect platform
            if $IS_MACOS; then
                sed -i '' 's/PLATFORM=".*"/PLATFORM="macos"/' "$config_file"
            elif $IS_WSL; then
                sed -i 's/PLATFORM=".*"/PLATFORM="wsl"/' "$config_file"
            elif $IS_LINUX; then
                sed -i 's/PLATFORM=".*"/PLATFORM="linux"/' "$config_file"
            fi
            
            # Set machine name
            local machine_name=$(hostname)
            sed -i "s/MACHINE_NAME=\".*\"/MACHINE_NAME=\"$machine_name\"/" "$config_file" 2>/dev/null || \
            sed -i '' "s/MACHINE_NAME=\".*\"/MACHINE_NAME=\"$machine_name\"/" "$config_file"
            
            log_success ".local-config created"
        else
            log_warning ".local-config.example not found, skipping local config"
        fi
    else
        log_info ".local-config already exists"
    fi
}

# Load .local-config
load_local_config() {
    local config_file="$SCRIPT_DIR/.local-config"
    
    if [[ -f "$config_file" ]]; then
        source "$config_file"
        log_info "Loaded .local-config"
        log_info "  Platform: ${PLATFORM:-unknown}"
        log_info "  Desktop: ${DESKTOP_ENV:-none}"
        log_info "  Optionals: ${INSTALLED_OPTIONALS:-none}"
    else
        log_warning ".local-config not found"
    fi
}

# Check if optional component is installed
is_component_installed() {
    local component="$1"
    [[ "$INSTALLED_OPTIONALS" == *"$component"* ]]
}

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
        if command_exists pacman; then
            PACKAGE_MANAGER="pacman"
        elif command_exists apt; then
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
            "pacman")
                if pacman -Q "$package" >/dev/null 2>&1; then
                    is_installed=true
                fi
                ;;
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
            "pacman")
                sudo pacman -S --needed --noconfirm "$package"
                ;;
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
        local packages=()
        
        # Base packages (cross-distro)
        packages+=("zsh" "git" "curl" "wget" "unzip" "zip" "ca-certificates")
        
        # Build tools (distro-specific)
        if [[ "$PACKAGE_MANAGER" == "pacman" ]]; then
            packages+=("base-devel")
        else
            packages+=("build-essential" "python3" "python3-pip" "nodejs" "npm")
        fi
        
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

# Function to setup fnm (Fast Node Manager)
setup_fnm() {
    log_info "Setting up fnm (Fast Node Manager) for Node.js..."
    
    # Check if fnm is already installed
    if command_exists fnm; then
        log_success "✓ fnm already installed"
        return 0
    fi
    
    # Install fnm
    if $IS_MACOS; then
        if command_exists brew; then
            log_info "Installing fnm via Homebrew..."
            brew install fnm
        else
            log_error "Homebrew not found. Please install Homebrew first."
            return 1
        fi
    else
        # Linux installation
        log_info "Installing fnm via curl..."
        curl -fsSL https://fnm.vercel.app/install | bash
    fi
    
    # Source fnm for current session
    export PATH="$HOME/.local/share/fnm:$PATH"
    eval "$(fnm env --use-on-cd)"
    
    log_success "fnm installed successfully"
}

# Function to install Node.js via fnm
install_node_fnm() {
    log_info "Installing Node.js via fnm..."
    
    # Source fnm for current session
    export PATH="$HOME/.local/share/fnm:$PATH"
    eval "$(fnm env --use-on-cd)"
    
    # Install latest LTS Node.js
    if ! command_exists node; then
        log_info "Installing Node.js LTS..."
        fnm install --lts
        fnm use --lts
        fnm default --lts
        log_success "Node.js LTS installed and set as default"
    else
        log_success "✓ Node.js already installed"
    fi
}

# Function to install modern tools via package manager
install_modern_tools() {
    log_info "Installing modern CLI tools..."
    
    if $IS_MACOS; then
        # macOS tools via Homebrew
        local packages=(
            "starship"     # Prompt
            "lsd"          # ls replacement
            "bat"          # cat replacement
            "ripgrep"      # grep replacement
            "fd"           # find replacement
            "fzf"          # fuzzy finder
            "zoxide"       # cd replacement
            "bottom"       # top replacement
            "procs"        # ps replacement
            "du-dust"      # du replacement
            "tealdeer"     # tldr
            "git-delta"    # git diff
            "lazygit"      # git TUI
            "sd"           # sed replacement
        )
        
        for package in "${packages[@]}"; do
            install_package "$package" "$package"
        done
    else
        # Linux tools
        local packages=(
            "fzf" "fd-find" "ripgrep" "bat"
        )
        
        # Update package list first
        if [[ "$PACKAGE_MANAGER" == "apt" ]]; then
            log_info "Updating package list for modern tools..."
            sudo apt update
        fi
        
        for package in "${packages[@]}"; do
            install_package "$package" "$package" || log_warning "⚠ $package not available via package manager"
        done
        
        # Install tools that need special handling on Linux
        install_starship_linux
        install_zoxide_linux
        install_lsd_linux
    fi
}

# Function to install starship on Linux
install_starship_linux() {
    if command_exists starship; then
        log_success "✓ starship already installed"
        return 0
    fi
    
    log_info "Installing starship..."
    curl -sS https://starship.rs/install.sh | sh -s -- --yes
    log_success "starship installed"
}

# Function to install zoxide on Linux
install_zoxide_linux() {
    if command_exists zoxide; then
        log_success "✓ zoxide already installed"
        return 0
    fi
    
    log_info "Installing zoxide..."
    curl -sS https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | bash
    log_success "zoxide installed"
}

# Function to install lsd on Linux
install_lsd_linux() {
    if command_exists lsd; then
        log_success "✓ lsd already installed"
        return 0
    fi
    
    log_info "Installing lsd from GitHub releases..."
    local lsd_version="1.0.0"
    local lsd_url="https://github.com/lsd-rs/lsd/releases/download/v${lsd_version}/lsd_${lsd_version}_amd64.deb"
    
    if [[ "$PACKAGE_MANAGER" == "apt" ]]; then
        wget -O /tmp/lsd.deb "$lsd_url"
        sudo dpkg -i /tmp/lsd.deb
        rm /tmp/lsd.deb
        log_success "lsd installed"
    else
        log_warning "lsd installation requires apt package manager"
    fi
}

# Function to setup fzf
setup_fzf() {
    log_info "Setting up fzf..."
    
    # Check if fzf is already installed
    if command_exists fzf; then
        log_success "✓ fzf already installed"
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
    
    log_success "Terminal configuration fixed"
}

# Function to create per-machine local aliases file (not in git)
create_local_aliases() {
  local alias_file="$HOME/.local-aliases"
  if [[ ! -f "$alias_file" ]]; then
    log_info "Creating local aliases file: $alias_file"
    mkdir -p "$HOME"
    cat > "$alias_file" <<'EOF'
# Local per-machine aliases (not tracked in git)
# Example:
# alias ll='ls -la'
EOF
    chmod 600 "$alias_file"
    log_success "Created $alias_file"
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

    # Create symlink using absolute path
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
    
    # Ensure local aliases file is created on this machine
    create_local_aliases
    
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
Dotfiles Installer v3.0 (Simplified)

Usage: ./install.sh [OPTIONS]

Options:
  --help, -h          Show this help message
  --skip-deps         Skip dependency installation (only install dotfiles)
  --skip-dotfiles     Skip dotfiles installation (only install dependencies)
  --dry-run           Show what would be installed without actually installing
  --verify            Verify the installation after completion
  --update            Update system packages (apt/brew) after installation

Examples:
  ./install.sh                    # Full installation
  ./install.sh --verify           # Full installation with verification
  ./install.sh --update           # Full installation + system update
  ./install.sh --skip-deps        # Only install dotfiles
  ./install.sh --skip-dotfiles    # Only install dependencies
  ./install.sh --dry-run          # Preview installation

This script will:
1. Detect your OS (macOS, Linux, WSL2)
2. Install all necessary dependencies
3. Setup development tools (Node.js via fnm)
4. Install and configure zsh with plugins
5. Create symlinks for all dotfiles
6. Install modern CLI tools (starship, lsd, bat, etc.)

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
        echo "  - zsh, git, curl, wget, python3, nodejs, npm (via apt/yum/dnf)"
    fi
    
    log_info ""
    log_info "Would setup tools:"
    echo "  - zinit (plugin manager)"
    echo "  - fnm (Fast Node Manager for Node.js)"
    echo "  - Node.js LTS (via fnm)"
    echo "  - Modern CLI tools (starship, lsd, bat, ripgrep, fzf, etc.)"
    
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
    
    log_success "Dry run complete - no changes made"
}

# Function to update system packages
update_system_packages() {
    log_info "Updating system packages..."
    
    if $IS_MACOS; then
        if command_exists brew; then
            log_info "Updating Homebrew packages..."
            brew update
            log_success "Homebrew packages updated"
        else
            log_warning "Homebrew not found, skipping system update"
        fi
    else
        # Linux package manager updates
        if command_exists apt; then
            log_info "Updating apt packages..."
            sudo apt update && sudo apt upgrade -y
            log_success "apt packages updated"
        elif command_exists yum; then
            log_info "Updating yum packages..."
            sudo yum update -y
            log_success "yum packages updated"
        elif command_exists dnf; then
            log_info "Updating dnf packages..."
            sudo dnf update -y
            log_success "dnf packages updated"
        else
            log_warning "No supported package manager found for system update"
        fi
    fi
}

# Main installation function
main_installation() {
    local skip_deps=false
    local skip_dotfiles=false
    local dry_run_mode=false
    local verify_mode=false
    local update_system=false
    
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
            --update)
                update_system=true
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
    
    log_info "=== Dotfiles Installer v3.0 (Simplified) ==="
    log_info "Detected OS: $OS_NAME ($(uname -s) $(uname -r))"
    log_info "Script directory: $SCRIPT_DIR"
    
    # Initialize and load local config
    init_local_config
    load_local_config
    
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
        setup_fnm
        
        log_info ""
        log_info "=== Installing Development Tools ==="
        install_node_fnm
        install_modern_tools
        setup_fzf
        
        log_info ""
        log_info "=== Configuring Environment ==="
        fix_terminal_config
    fi
    
    # Update system packages if requested
    if $update_system; then
        log_info ""
        log_info "=== Updating System Packages ==="
        update_system_packages
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
}

# Run installation
main_installation "$@"

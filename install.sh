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
            "eza"          # ls replacement (modern, better than lsd)
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
        install_eza_linux
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

# Function to install eza on Linux
install_eza_linux() {
    if command_exists eza; then
        log_success "✓ eza already installed"
        # Mark as explicitly installed to prevent auto-removal
        if command_exists paru; then
            paru -D --asexplicit eza 2>/dev/null || true
        elif command_exists pacman; then
            sudo pacman -D --asexplicit eza 2>/dev/null || true
        fi
        return 0
    fi
    
    log_info "Installing eza..."
    
    # Try package manager first (most distros have it now)
    if command_exists paru; then
        # Arch/CachyOS - use paru
        log_info "Installing eza via paru..."
        paru -S --needed --noconfirm eza
        # Mark as explicitly installed
        paru -D --asexplicit eza
        log_success "eza installed via paru"
        return 0
    elif command_exists yay; then
        # Arch - use yay
        log_info "Installing eza via yay..."
        yay -S --needed --noconfirm eza
        # Mark as explicitly installed
        yay -D --asexplicit eza
        log_success "eza installed via yay"
        return 0
    elif command_exists pacman; then
        # Arch - use pacman directly
        log_info "Installing eza via pacman..."
        sudo pacman -S --needed --noconfirm eza
        # Mark as explicitly installed
        sudo pacman -D --asexplicit eza
        log_success "eza installed via pacman"
        return 0
    elif [[ "$PACKAGE_MANAGER" == "apt" ]]; then
        # Debian/Ubuntu - eza is in repos for newer versions
        if sudo apt install -y eza 2>/dev/null; then
            log_success "eza installed via apt"
            return 0
        fi
    fi
    
    # Fallback: suggest manual installation via cargo or package manager
    log_warning "eza not available via package manager"
    log_info "Install manually with: cargo install eza"
    log_info "Or on Arch-based: paru -S eza"
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

# Function to setup gaming scripts
setup_gaming() {
    log_info "Setting up gaming scripts..."
    
    # Create necessary directories
    mkdir -p "$HOME/bin"
    mkdir -p "$HOME/.config/game-launcher"
    
    # Check for gaming tools (optional, just warn if missing)
    if ! command_exists gamemoderun; then
        log_warning "gamemode not found - install with: sudo pacman -S gamemode lib32-gamemode"
    fi
    
    if ! command_exists mangohud; then
        log_warning "mangohud not found - install with: sudo pacman -S mangohud"
    fi
    
    # Create symlinks for gaming scripts
    if [[ -d "$SCRIPT_DIR/gaming" ]]; then
        create_symlink "$SCRIPT_DIR/gaming/bin/gamelaunch" "$HOME/bin/gamelaunch" "gamelaunch script"
        create_symlink "$SCRIPT_DIR/gaming/config/presets.conf" "$HOME/.config/game-launcher/presets.conf" "gaming presets"
        create_symlink "$SCRIPT_DIR/gaming/README.md" "$HOME/.config/game-launcher/README.md" "gaming README"
        
        # Ensure script is executable
        if [[ -f "$SCRIPT_DIR/gaming/bin/gamelaunch" ]]; then
            chmod +x "$SCRIPT_DIR/gaming/bin/gamelaunch"
        fi
        
        log_success "Gaming scripts installed"
        log_info "  Use in Steam: gamelaunch --preset diablo4 %command%"
        log_info "  Config: ~/.config/game-launcher/presets.conf"
    else
        log_info "Gaming scripts directory not found, skipping"
    fi
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
    create_symlink "$SCRIPT_DIR/.config/starship.toml" "$HOME/.config/starship.toml" "starship config"
    
    # Modern CLI tool configs (cross-platform)
    create_symlink "$SCRIPT_DIR/.config/lazygit" "$HOME/.config/lazygit" "lazygit config"
    create_symlink "$SCRIPT_DIR/.config/bat" "$HOME/.config/bat" "bat config"
    create_symlink "$SCRIPT_DIR/.config/procs" "$HOME/.config/procs" "procs config"
    
    # Platform-specific configs
    if $IS_MACOS; then
        create_symlink "$SCRIPT_DIR/.config/ghostty" "$HOME/.config/ghostty" "ghostty config"
    elif $IS_LINUX; then
        # Run Linux-specific installer
        if [[ -f "$SCRIPT_DIR/linux/install-linux.sh" ]]; then
            log_info ""
            log_info "=== Linux-Specific Configuration ==="
            "$SCRIPT_DIR/linux/install-linux.sh"
        else
            log_warning "Linux installer not found, skipping Linux-specific setup"
        fi
    fi
    
    # Setup gaming scripts (cross-platform)
    setup_gaming
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

# Function to show interactive menu
show_interactive_menu() {
    clear
    cat <<'EOF'
╔════════════════════════════════════════════════════════════════════╗
║           Dotfiles Installer v3.0 - Interactive Setup             ║
╚════════════════════════════════════════════════════════════════════╝

EOF
    log_info "Detected OS: $OS_NAME ($(uname -s))"
    log_info "Package Manager: $PACKAGE_MANAGER"
    echo ""
    
    cat <<'EOF'
Select installation option:

  1) Full Setup (Recommended)
     └─ Install everything: dependencies, tools, dotfiles, and gaming

  2) Minimal Setup
     └─ Basic dotfiles + essential tools only

  3) Custom Components
     └─ Choose specific components to install

  4) Gaming Only
     └─ Install gaming launcher and presets

  5) Platform-Specific Only (Ghostty, etc.)
     └─ Install platform-specific configs

  6) Development Tools Only
     └─ Install Node.js, modern CLI tools

  7) Dry Run
     └─ Preview what would be installed

  0) Exit

EOF
    echo -n "Enter your choice [0-7]: "
    read -r choice
    echo ""
    
    case $choice in
        1) install_mode="full" ;;
        2) install_mode="minimal" ;;
        3) install_mode="custom" ;;
        4) install_mode="gaming" ;;
        5) install_mode="platform" ;;
        6) install_mode="devtools" ;;
        7) dry_run; exit 0 ;;
        0) log_info "Exiting..."; exit 0 ;;
        *) log_error "Invalid choice"; show_interactive_menu ;;
    esac
}

# Function to show custom components menu
show_custom_menu() {
    clear
    cat <<'EOF'
╔════════════════════════════════════════════════════════════════════╗
║                    Custom Component Selection                      ║
╚════════════════════════════════════════════════════════════════════╝

Select components to install (space-separated numbers, e.g., "1 3 5"):

  1) Dependencies (zsh, git, curl, etc.)
  2) Development Tools (Node.js, fnm, modern CLI tools)
  3) Basic Dotfiles (zshrc, gitconfig, starship)
  4) Gaming Launcher & Presets
  5) Platform-Specific Configs (Ghostty, etc.)
  6) Modern CLI Tools (bat, eza, ripgrep, etc.)

  0) Back to main menu

EOF
    echo -n "Enter your choices: "
    read -r custom_choices
    echo ""
    
    if [[ "$custom_choices" == "0" ]]; then
        show_interactive_menu
        return
    fi
    
    # Parse custom choices
    INSTALL_DEPS=false
    INSTALL_DEVTOOLS=false
    INSTALL_DOTFILES=false
    INSTALL_GAMING=false
    INSTALL_PLATFORM=false
    INSTALL_MODERN_TOOLS=false
    
    for choice in $custom_choices; do
        case $choice in
            1) INSTALL_DEPS=true ;;
            2) INSTALL_DEVTOOLS=true ;;
            3) INSTALL_DOTFILES=true ;;
            4) INSTALL_GAMING=true ;;
            5) INSTALL_PLATFORM=true ;;
            6) INSTALL_MODERN_TOOLS=true ;;
            *) log_warning "Invalid choice: $choice" ;;
        esac
    done
}

# Function to show help
show_help() {
    cat <<'EOF'
Dotfiles Installer v3.0 (Simplified)

Usage: ./install.sh [OPTIONS]

Options:
  --help, -h          Show this help message
  --interactive, -i   Interactive menu mode (default)
  --full              Full installation (all components)
  --minimal           Minimal installation (basic dotfiles only)
  --gaming            Gaming setup only
  --skip-deps         Skip dependency installation
  --skip-dotfiles     Skip dotfiles installation
  --dry-run           Show what would be installed
  --verify            Verify the installation after completion
  --update            Update system packages

Examples:
  ./install.sh                    # Interactive menu
  ./install.sh --full             # Full installation
  ./install.sh --gaming           # Gaming setup only
  ./install.sh --minimal          # Minimal setup
  ./install.sh --dry-run          # Preview installation

This script will:
1. Detect your OS (macOS, Linux, WSL2)
2. Install selected components
3. Setup development tools (Node.js via fnm)
4. Install and configure zsh with plugins
5. Create symlinks for dotfiles
6. Setup gaming launcher (if selected)

Supported platforms:
- macOS (with Homebrew)
- Linux (Ubuntu/Debian, Arch, CentOS/RHEL)
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
    local install_mode=""
    local interactive_mode=true
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --help|-h)
                show_help
                exit 0
                ;;
            --interactive|-i)
                interactive_mode=true
                shift
                ;;
            --full)
                install_mode="full"
                interactive_mode=false
                shift
                ;;
            --minimal)
                install_mode="minimal"
                interactive_mode=false
                shift
                ;;
            --gaming)
                install_mode="gaming"
                interactive_mode=false
                shift
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
                dry_run
                exit 0
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
    
    # Show interactive menu if no mode specified
    if [[ -z "$install_mode" ]] && $interactive_mode; then
        show_interactive_menu
    fi
    
    # Handle custom component selection
    if [[ "$install_mode" == "custom" ]]; then
        show_custom_menu
    fi
    
    # Banner
    log_info "=== Dotfiles Installer v3.0 ==="
    log_info "Detected OS: $OS_NAME ($(uname -s) $(uname -r))"
    log_info "Script directory: $SCRIPT_DIR"
    log_info "Package manager: $PACKAGE_MANAGER"
    echo ""
    
    # Execute based on mode
    case $install_mode in
        full)
            log_info "=== Running Full Setup ==="
            install_full_setup
            ;;
        minimal)
            log_info "=== Running Minimal Setup ==="
            install_minimal_setup
            ;;
        custom)
            log_info "=== Running Custom Setup ==="
            install_custom_setup
            ;;
        gaming)
            log_info "=== Running Gaming Setup ==="
            install_gaming_only
            ;;
        platform)
            log_info "=== Running Platform-Specific Setup ==="
            install_platform_specific
            ;;
        devtools)
            log_info "=== Running Development Tools Setup ==="
            install_devtools_only
            ;;
        *)
            # Fallback to old behavior for backward compatibility
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
            ;;
    esac
    
    if $verify_mode; then
        log_info ""
        log_info "=== Verifying Installation ==="
        verify_zsh_setup
    fi
    
    show_completion_message
}

# Installation mode functions
install_full_setup() {
    log_info "Installing all components..."
    
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
    
    log_info ""
    log_info "=== Installing Dotfiles ==="
    install_dotfiles
}

install_minimal_setup() {
    log_info "Installing minimal components..."
    
    log_info ""
    log_info "=== Installing Basic Packages ==="
    install_basic_packages
    setup_zsh
    
    log_info ""
    log_info "=== Installing Basic Dotfiles ==="
    # Basic dotfiles only
    create_symlink "$SCRIPT_DIR/.zshrc" "$HOME/.zshrc" ".zshrc"
    create_symlink "$SCRIPT_DIR/.gitconfig" "$HOME/.gitconfig" ".gitconfig"
    create_symlink "$SCRIPT_DIR/.gitignore_global" "$HOME/.gitignore_global" ".gitignore_global"
    create_symlink "$SCRIPT_DIR/.config/starship.toml" "$HOME/.config/starship.toml" "starship config"
}

install_custom_setup() {
    if $INSTALL_DEPS; then
        log_info ""
        log_info "=== Installing Dependencies ==="
        install_basic_packages
        setup_zsh
        setup_zinit
    fi
    
    if $INSTALL_DEVTOOLS; then
        log_info ""
        log_info "=== Installing Development Tools ==="
        setup_fnm
        install_node_fnm
    fi
    
    if $INSTALL_MODERN_TOOLS; then
        log_info ""
        log_info "=== Installing Modern CLI Tools ==="
        install_modern_tools
        setup_fzf
    fi
    
    if $INSTALL_DOTFILES; then
        log_info ""
        log_info "=== Installing Dotfiles ==="
        create_symlink "$SCRIPT_DIR/.zshrc" "$HOME/.zshrc" ".zshrc"
        create_symlink "$SCRIPT_DIR/.gitconfig" "$HOME/.gitconfig" ".gitconfig"
        create_symlink "$SCRIPT_DIR/.gitignore_global" "$HOME/.gitignore_global" ".gitignore_global"
        create_symlink "$SCRIPT_DIR/.config/starship.toml" "$HOME/.config/starship.toml" "starship config"
        create_symlink "$SCRIPT_DIR/.config/lazygit" "$HOME/.config/lazygit" "lazygit config"
        create_symlink "$SCRIPT_DIR/.config/bat" "$HOME/.config/bat" "bat config"
        create_symlink "$SCRIPT_DIR/.config/procs" "$HOME/.config/procs" "procs config"
    fi
    
    if $INSTALL_GAMING; then
        log_info ""
        log_info "=== Installing Gaming Setup ==="
        setup_gaming
    fi
    
    if $INSTALL_PLATFORM; then
        log_info ""
        log_info "=== Installing Platform-Specific Configs ==="
        if $IS_MACOS; then
            create_symlink "$SCRIPT_DIR/.config/ghostty" "$HOME/.config/ghostty" "ghostty config"
        elif $IS_LINUX; then
            if [[ -f "$SCRIPT_DIR/linux/install-linux.sh" ]]; then
                "$SCRIPT_DIR/linux/install-linux.sh"
            fi
        fi
    fi
}

install_gaming_only() {
    log_info "Installing gaming launcher and presets..."
    setup_gaming
    log_success "Gaming setup complete!"
    log_info ""
    log_info "Usage:"
    log_info "  gamelaunch --preset diablo4 %command%"
    log_info "  gamelaunch --help"
    log_info ""
    log_info "Documentation: ~/.config/dotfiles/gaming/GAMES.md"
}

install_platform_specific() {
    if $IS_MACOS; then
        log_info "Installing macOS-specific configs..."
        create_symlink "$SCRIPT_DIR/.config/ghostty" "$HOME/.config/ghostty" "ghostty config"
    elif $IS_LINUX; then
        log_info "Installing Linux-specific configs..."
        if [[ -f "$SCRIPT_DIR/linux/install-linux.sh" ]]; then
            "$SCRIPT_DIR/linux/install-linux.sh"
        else
            log_warning "Linux installer not found"
        fi
    fi
}

install_devtools_only() {
    log_info "Installing development tools..."
    
    log_info ""
    log_info "=== Installing Node.js ==="
    setup_fnm
    install_node_fnm
    
    log_info ""
    log_info "=== Installing Modern CLI Tools ==="
    install_modern_tools
    setup_fzf
}

show_completion_message() {
    log_info ""
    log_success "=== Installation Complete! ==="
    log_info ""
    log_info "Next steps:"
    log_info "1. Log out and log back in (or restart your terminal)"
    log_info "2. Your new setup will be active"
    
    if [[ "$install_mode" == "gaming" ]] || $INSTALL_GAMING; then
        log_info "3. Try: gamelaunch --help"
        log_info "4. Read docs: cat ~/.config/dotfiles/gaming/QUICKSTART.md"
    else
        log_info "3. Run 'starship --version' to verify the prompt"
    fi
    
    log_info ""
    log_info "If you encounter any issues:"
    log_info "- Check ~/.zshrc for any errors"
    log_info "- Run 'source ~/.zshrc' to reload configuration"
    log_info "- Run './status.sh' to check component status"
}

# Run installation
main_installation "$@"

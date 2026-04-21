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
        return 0
    fi

    log_info "Installing eza..."

    if [[ "$PACKAGE_MANAGER" == "apt" ]]; then
        if sudo apt install -y eza 2>/dev/null; then
            log_success "eza installed via apt"
            return 0
        fi
    fi

    log_warning "eza not available via package manager"
    log_info "Install manually: sudo apt install eza  # or cargo install eza"
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
        log_warning "gamemode not found - install with: sudo apt install gamemode"
    fi

    if ! command_exists mangohud; then
        log_warning "mangohud not found - install with: sudo apt install mangohud"
    fi

    # Create symlinks for gaming scripts
    if [[ -d "$SCRIPT_DIR/gaming" ]]; then
        create_symlink "$SCRIPT_DIR/gaming/bin/gamelaunch" "$HOME/bin/gamelaunch" "gamelaunch script"
        create_symlink "$SCRIPT_DIR/gaming/config/presets.conf" "$HOME/.config/game-launcher/presets.conf" "gaming presets"
        
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

    # Codex CLI config
    create_symlink "$SCRIPT_DIR/.codex" "$HOME/.codex" "codex config"

    # tmux config
    create_symlink "$SCRIPT_DIR/.config/tmux" "$HOME/.config/tmux" "tmux config"

    # Local secrets (API keys, tokens - not tracked in git)
    if [[ ! -f "$SCRIPT_DIR/.local-secrets" ]]; then
        if [[ -f "$SCRIPT_DIR/.local-secrets.example" ]]; then
            log_info "Creating .local-secrets from example template..."
            cp "$SCRIPT_DIR/.local-secrets.example" "$SCRIPT_DIR/.local-secrets"
            chmod 600 "$SCRIPT_DIR/.local-secrets"
            log_warning "Edit $SCRIPT_DIR/.local-secrets and add your actual API keys"
        fi
    fi
    if [[ -f "$SCRIPT_DIR/.local-secrets" ]]; then
        create_symlink "$SCRIPT_DIR/.local-secrets" "$HOME/.local-secrets" "local secrets"
    fi

    # Platform-specific configs
    if $IS_MACOS; then
        create_symlink "$SCRIPT_DIR/macos/ghostty" "$HOME/.config/ghostty" "ghostty config"
    elif $IS_LINUX; then
        # Run Linux-specific installer (Ghostty on native Linux, Windows Terminal on WSL)
        if [[ -f "$SCRIPT_DIR/linux/install-linux.sh" ]]; then
            log_info ""
            log_info "=== Linux-Specific Configuration ==="
            "$SCRIPT_DIR/linux/install-linux.sh"
        else
            log_warning "Linux installer not found, skipping Linux-specific setup"
        fi
        # Windows Terminal (WSL only)
        if grep -q Microsoft /proc/version 2>/dev/null; then
            for wt_dir in "/mnt/c/Users/$USER/AppData/Local/Packages/Microsoft.WindowsTerminal_8wekyb3d8bbwe/LocalState" \
                          "/mnt/c/Users/$USERNAME/AppData/Local/Packages/Microsoft.WindowsTerminal_8wekyb3d8bbwe/LocalState"; do
                if [[ -d "$wt_dir" ]] && [[ -f "$SCRIPT_DIR/wsl/windows-terminal/settings.json" ]]; then
                    create_symlink "$SCRIPT_DIR/wsl/windows-terminal/settings.json" "$wt_dir/settings.json" "Windows Terminal config"
                    break
                fi
            done
        fi
    fi

    # Gaming scripts (optional - skip on WSL, prompt on macOS/Linux)
    if grep -q Microsoft /proc/version 2>/dev/null; then
        log_info "WSL detected - skipping gamelaunch (not used on WSL)"
    elif [[ -t 0 ]]; then
        echo ""
        read -p "Install gamelaunch utils? (Steam gaming scripts) [y/N]: " -n 1 -r install_gaming_reply
        echo ""
        if [[ "$install_gaming_reply" =~ ^[Yy]$ ]]; then
            setup_gaming
        else
            log_info "Skipping gamelaunch setup"
        fi
    else
        log_info "Non-interactive - skipping gamelaunch (run with --gaming to add later)"
    fi
}

# Function to setup Cursor settings sync
setup_cursor_sync() {
    log_info "Setting up Cursor settings sync..."
    
    # Check if setup-cursor-sync.sh exists
    if [[ ! -f "$SCRIPT_DIR/scripts/cursor/setup-cursor-sync.sh" ]]; then
        log_warning "setup-cursor-sync.sh not found, skipping Cursor sync"
        return 0
    fi

    # Run the Cursor sync setup script (from dotfiles root so paths resolve)
    (cd "$SCRIPT_DIR" && bash scripts/cursor/setup-cursor-sync.sh)
    
    log_success "Cursor settings sync setup complete"
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

# Function to check installation status
check_install_status() {
    echo -e "${BLUE}Current Status:${NC}"
    
    # Check zsh
    if command_exists zsh && [[ "$SHELL" == *"zsh"* ]]; then
        echo -e "  ${GREEN}✓${NC} zsh (default shell)"
    elif command_exists zsh; then
        echo -e "  ${YELLOW}◐${NC} zsh (installed, not default)"
    else
        echo -e "  ${RED}✗${NC} zsh"
    fi
    
    # Check fnm/Node.js
    if command_exists fnm && command_exists node; then
        local node_version=$(node --version 2>/dev/null)
        echo -e "  ${GREEN}✓${NC} Node.js ($node_version via fnm)"
    elif command_exists node; then
        echo -e "  ${YELLOW}◐${NC} Node.js (not via fnm)"
    else
        echo -e "  ${RED}✗${NC} Node.js"
    fi
    
    # Check modern tools
    local tools_installed=0
    local tools_total=5
    command_exists starship && ((tools_installed++))
    command_exists eza && ((tools_installed++))
    command_exists bat && ((tools_installed++))
    command_exists ripgrep && ((tools_installed++))
    command_exists fzf && ((tools_installed++))
    
    if [[ $tools_installed -eq $tools_total ]]; then
        echo -e "  ${GREEN}✓${NC} Modern CLI tools ($tools_installed/$tools_total)"
    elif [[ $tools_installed -gt 0 ]]; then
        echo -e "  ${YELLOW}◐${NC} Modern CLI tools ($tools_installed/$tools_total)"
    else
        echo -e "  ${RED}✗${NC} Modern CLI tools (0/$tools_total)"
    fi
    
    # Check Cursor sync
    local cursor_synced=false
    if $IS_MACOS; then
        [[ -L "$HOME/Library/Application Support/Cursor/User/settings.json" ]] && cursor_synced=true
    else
        [[ -L "$HOME/.config/Cursor/User/settings.json" ]] && cursor_synced=true
    fi
    
    if $cursor_synced; then
        echo -e "  ${GREEN}✓${NC} Cursor settings synced"
    else
        echo -e "  ${RED}✗${NC} Cursor settings not synced"
    fi
    
    # Check dotfiles
    if [[ -L "$HOME/.zshrc" ]] && [[ -L "$HOME/.gitconfig" ]]; then
        echo -e "  ${GREEN}✓${NC} Dotfiles linked"
    elif [[ -f "$HOME/.zshrc" ]]; then
        echo -e "  ${YELLOW}◐${NC} Dotfiles exist (not linked)"
    else
        echo -e "  ${RED}✗${NC} Dotfiles not installed"
    fi
    
    # Check gaming
    if [[ -f "$HOME/bin/gamelaunch" ]]; then
        echo -e "  ${GREEN}✓${NC} Gaming launcher"
    else
        echo -e "  ${RED}✗${NC} Gaming launcher"
    fi
    
    echo ""
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
    
    # Show installation status
    check_install_status
    
    cat <<'EOF'
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📦 COMPLETE SETUPS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  1) Full Setup (Recommended) [~10-15 min]
     └─ Everything: deps, tools, dotfiles, gaming, Cursor

  2) Minimal Setup [~3-5 min]
     └─ Basic dotfiles + essential tools only

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🎯 QUICK INSTALLS (Single Component)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  3) Cursor Settings Sync [~30 sec]
     └─ Link Cursor settings/keybindings to dotfiles

  4) Gaming Launcher [~1 min]
     └─ Install gaming scripts and presets

  5) Development Tools [~5-8 min]
     └─ Node.js (fnm), modern CLI tools

  6) Platform Configs [~2-3 min]
     └─ Ghostty, Windows Terminal (WSL)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
⚙️  ADVANCED
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  7) Custom Components
     └─ Pick and choose what to install

  8) Update Existing Setup
     └─ Re-run symlinks, update tools, refresh configs

  9) Dry Run
     └─ Preview installation without changes

  0) Exit

EOF
    echo -n "Enter your choice [0-9]: "
    read -r choice
    echo ""
    
    case $choice in
        1) install_mode="full" ;;
        2) install_mode="minimal" ;;
        3) install_mode="cursor" ;;
        4) install_mode="gaming" ;;
        5) install_mode="devtools" ;;
        6) install_mode="platform" ;;
        7) install_mode="custom" ;;
        8) install_mode="update" ;;
        9) dry_run; exit 0 ;;
        0) log_info "Exiting..."; exit 0 ;;
        *) log_error "Invalid choice"; show_interactive_menu ;;
    esac
}

# Function to show custom components menu with interactive selection
show_custom_menu() {
    # Component states (0 = unchecked, 1 = checked)
    local -a selected=(0 0 0 0 0 0 0)
    local current=0
    local key
    
    while true; do
        clear
        cat <<'EOF'
╔════════════════════════════════════════════════════════════════════╗
║                    Custom Component Selection                      ║
╚════════════════════════════════════════════════════════════════════╝

Use ↑/↓ arrows to navigate, SPACE to toggle, ENTER to confirm, q to cancel

EOF
        
        # Component list
        local -a components=(
            "Dependencies [~2-3 min]|zsh, git, curl, build tools"
            "Development Tools [~5-8 min]|Node.js via fnm, package managers"
            "Modern CLI Tools [~3-5 min]|starship, eza, bat, ripgrep, fzf, zoxide"
            "Basic Dotfiles [~1 min]|zshrc, gitconfig, starship config"
            "Cursor Settings Sync [~30 sec]|Link Cursor settings to dotfiles"
            "Gaming Launcher [~1 min]|Gaming scripts and presets"
            "Platform Configs [~2-3 min]|Ghostty, Windows Terminal (WSL)"
        )
        
        # Display components
        for i in "${!components[@]}"; do
            IFS='|' read -r title desc <<< "${components[$i]}"
            
            # Highlight current selection
            if [[ $i -eq $current ]]; then
                echo -ne "${CYAN}> "
            else
                echo -n "  "
            fi
            
            # Show checkbox
            if [[ ${selected[$i]} -eq 1 ]]; then
                echo -ne "${GREEN}[✓]${NC} "
            else
                echo -ne "[ ] "
            fi
            
            # Show component info
            echo -e "${NC}$((i+1))) $title"
            echo "     └─ $desc"
            echo ""
        done
        
        echo ""
        echo -e "${BLUE}Selected components: ${NC}"
        local has_selection=false
        for i in "${!components[@]}"; do
            if [[ ${selected[$i]} -eq 1 ]]; then
                IFS='|' read -r title desc <<< "${components[$i]}"
                echo "  • $title"
                has_selection=true
            fi
        done
        
        if ! $has_selection; then
            echo "  (none)"
        fi
        
        echo ""
        echo "Press ENTER to install selected components, or 'q' to cancel"
        
        # Read single key
        read -rsn1 key
        
        case "$key" in
            $'\x1b')  # ESC sequence (arrow keys)
                read -rsn2 key  # Read the rest of the escape sequence
                case "$key" in
                    '[A')  # Up arrow
                        ((current--))
                        [[ $current -lt 0 ]] && current=$((${#components[@]} - 1))
                        ;;
                    '[B')  # Down arrow
                        ((current++))
                        [[ $current -ge ${#components[@]} ]] && current=0
                        ;;
                esac
                ;;
            ' ')  # Space - toggle selection
                if [[ ${selected[$current]} -eq 0 ]]; then
                    selected[$current]=1
                else
                    selected[$current]=0
                fi
                ;;
            '')  # Enter - confirm
                # Check if any component is selected
                local any_selected=false
                for s in "${selected[@]}"; do
                    [[ $s -eq 1 ]] && any_selected=true && break
                done
                
                if ! $any_selected; then
                    log_warning "No components selected"
                    sleep 2
                    show_interactive_menu
                    return
                fi
                
                # Set install flags based on selections
                INSTALL_DEPS=${selected[0]}
                INSTALL_DEVTOOLS=${selected[1]}
                INSTALL_MODERN_TOOLS=${selected[2]}
                INSTALL_DOTFILES=${selected[3]}
                INSTALL_CURSOR=${selected[4]}
                INSTALL_GAMING=${selected[5]}
                INSTALL_PLATFORM=${selected[6]}
                
                # Convert to boolean
                [[ $INSTALL_DEPS -eq 1 ]] && INSTALL_DEPS=true || INSTALL_DEPS=false
                [[ $INSTALL_DEVTOOLS -eq 1 ]] && INSTALL_DEVTOOLS=true || INSTALL_DEVTOOLS=false
                [[ $INSTALL_MODERN_TOOLS -eq 1 ]] && INSTALL_MODERN_TOOLS=true || INSTALL_MODERN_TOOLS=false
                [[ $INSTALL_DOTFILES -eq 1 ]] && INSTALL_DOTFILES=true || INSTALL_DOTFILES=false
                [[ $INSTALL_CURSOR -eq 1 ]] && INSTALL_CURSOR=true || INSTALL_CURSOR=false
                [[ $INSTALL_GAMING -eq 1 ]] && INSTALL_GAMING=true || INSTALL_GAMING=false
                [[ $INSTALL_PLATFORM -eq 1 ]] && INSTALL_PLATFORM=true || INSTALL_PLATFORM=false
                
                clear
                return
                ;;
            'q'|'Q')  # Quit
                show_interactive_menu
                return
                ;;
            [1-7])  # Number keys - toggle directly
                local idx=$((key - 1))
                if [[ ${selected[$idx]} -eq 0 ]]; then
                    selected[$idx]=1
                else
                    selected[$idx]=0
                fi
                ;;
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
  --cursor            Cursor settings sync only
  --update            Update existing setup (refresh symlinks)
  --skip-deps         Skip dependency installation
  --skip-dotfiles     Skip dotfiles installation
  --dry-run           Show what would be installed
  --verify            Verify the installation after completion
  --update            Update system packages

Examples:
  ./install.sh                    # Interactive menu
  ./install.sh --full             # Full installation
  ./install.sh --gaming           # Gaming setup only
  ./install.sh --cursor           # Cursor settings sync only
  ./install.sh --update           # Update existing setup
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
    echo "  - ~/.config/tmux/"
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
            --cursor)
                install_mode="cursor"
                interactive_mode=false
                shift
                ;;
            --update)
                install_mode="update"
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
        cursor)
            log_info "=== Running Cursor Settings Sync ==="
            install_cursor_only
            ;;
        update)
            log_info "=== Running Update ==="
            install_update_setup
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
                
                log_info ""
                log_info "=== Setting up Cursor Settings Sync ==="
                setup_cursor_sync
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
    
    log_info ""
    log_info "=== Setting up Cursor Settings Sync ==="
    setup_cursor_sync
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
    create_symlink "$SCRIPT_DIR/.codex" "$HOME/.codex" "codex config"

    # Local secrets
    if [[ ! -f "$SCRIPT_DIR/.local-secrets" ]]; then
        if [[ -f "$SCRIPT_DIR/.local-secrets.example" ]]; then
            cp "$SCRIPT_DIR/.local-secrets.example" "$SCRIPT_DIR/.local-secrets"
            chmod 600 "$SCRIPT_DIR/.local-secrets"
            log_warning "Edit $SCRIPT_DIR/.local-secrets and add your actual API keys"
        fi
    fi
    if [[ -f "$SCRIPT_DIR/.local-secrets" ]]; then
        create_symlink "$SCRIPT_DIR/.local-secrets" "$HOME/.local-secrets" "local secrets"
    fi
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
        create_symlink "$SCRIPT_DIR/.codex" "$HOME/.codex" "codex config"
        create_symlink "$SCRIPT_DIR/.config/tmux" "$HOME/.config/tmux" "tmux config"
        # Local secrets
        if [[ ! -f "$SCRIPT_DIR/.local-secrets" ]]; then
            if [[ -f "$SCRIPT_DIR/.local-secrets.example" ]]; then
                cp "$SCRIPT_DIR/.local-secrets.example" "$SCRIPT_DIR/.local-secrets"
                chmod 600 "$SCRIPT_DIR/.local-secrets"
                log_warning "Edit $SCRIPT_DIR/.local-secrets and add your actual API keys"
            fi
        fi
        if [[ -f "$SCRIPT_DIR/.local-secrets" ]]; then
            create_symlink "$SCRIPT_DIR/.local-secrets" "$HOME/.local-secrets" "local secrets"
        fi
    fi
    
    if $INSTALL_CURSOR; then
        log_info ""
        log_info "=== Setting up Cursor Settings Sync ==="
        setup_cursor_sync
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
    log_info "Config: ~/.config/game-launcher/presets.conf"
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

install_cursor_only() {
    log_info "Setting up Cursor settings sync..."
    setup_cursor_sync
    log_success "Cursor settings sync complete!"
    log_info ""
    log_info "Your Cursor settings are now linked to dotfiles:"
    log_info "  - settings.json"
    log_info "  - keybindings.json"
    log_info "  - snippets/"
    log_info "  - extensions.json (list of installed extensions)"
    log_info ""
    
    # Offer to install extensions
    if [[ -f "$SCRIPT_DIR/.config/cursor/extensions.json" ]]; then
        EXTENSION_COUNT=$(jq '. | length' "$SCRIPT_DIR/.config/cursor/extensions.json" 2>/dev/null || echo "0")
        
        if [[ "$EXTENSION_COUNT" -gt 0 ]]; then
            log_info "Found $EXTENSION_COUNT extensions in extensions.json"
            echo ""
            echo -n "Do you want to install all extensions now? [y/N]: "
            read -r response
            
            if [[ "$response" =~ ^[Yy]$ ]]; then
                log_info ""
                log_info "Installing extensions..."
                if [[ -f "$SCRIPT_DIR/install-cursor-extensions.sh" ]]; then
                    bash "$SCRIPT_DIR/install-cursor-extensions.sh"
                else
                    log_error "install-cursor-extensions.sh not found"
                fi
            else
                log_info "Skipping extension installation"
                log_info "To install extensions later, run: ./install-cursor-extensions.sh"
            fi
        fi
    fi
    
    log_info ""
    log_info "Changes in Cursor will be reflected in your dotfiles."
    log_info "Commit and push to sync across machines."
    log_info ""
    log_info "To update extensions list: ./update-cursor-extensions.sh"
}

install_update_setup() {
    log_info "Updating existing setup..."
    log_info "This will refresh symlinks and update configurations."
    echo ""
    
    # Re-run dotfiles installation (updates symlinks)
    log_info ""
    log_info "=== Updating Dotfiles Symlinks ==="
    install_dotfiles
    
    # Update Cursor sync if it exists
    if $IS_MACOS; then
        if [[ -d "$HOME/Library/Application Support/Cursor" ]]; then
            log_info ""
            log_info "=== Updating Cursor Settings Sync ==="
            setup_cursor_sync
        fi
    else
        if [[ -d "$HOME/.config/Cursor" ]]; then
            log_info ""
            log_info "=== Updating Cursor Settings Sync ==="
            setup_cursor_sync
        fi
    fi
    
    # Update gaming scripts if they exist (and not on WSL - remove if present)
    if grep -q Microsoft /proc/version 2>/dev/null; then
        if [[ -L "$HOME/bin/gamelaunch" ]] || [[ -f "$HOME/bin/gamelaunch" ]]; then
            log_info "Removing gamelaunch from WSL (not used here)"
            rm -f "$HOME/bin/gamelaunch" "$HOME/bin/gamelaunch-gen" 2>/dev/null
            rm -f "$HOME/.config/game-launcher/presets.conf" 2>/dev/null
            rmdir "$HOME/.config/game-launcher" 2>/dev/null || true
        fi
    elif [[ -f "$HOME/bin/gamelaunch" ]]; then
        log_info ""
        log_info "=== Updating Gaming Scripts ==="
        setup_gaming
    fi
    
    log_success "Update complete!"
    log_info ""
    log_info "All symlinks have been refreshed."
    log_info "Run 'source ~/.zshrc' to reload your shell configuration."
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

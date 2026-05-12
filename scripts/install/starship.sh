#!/usr/bin/env bash
# Cross-platform Starship Installation
# Installs starship (prompt) on all platforms

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

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to install starship
install_starship() {
    log_info "Installing Starship prompt..."

    if command_exists starship; then
        log_success "✓ Starship already installed"
        return 0
    fi

    if $IS_MACOS; then
        # macOS: Use Homebrew
        if command_exists brew; then
            log_info "Installing starship via Homebrew..."
            brew install starship
        else
            log_warning "Homebrew not found, installing via curl..."
            curl -sS https://starship.rs/install.sh | sh
        fi
    else
        # Linux/WSL: Use official installer
        log_info "Installing starship via official installer..."
        curl -sS https://starship.rs/install.sh | sh
    fi

    # Verify installation
    if command_exists starship; then
        log_success "Starship installed successfully"
        starship --version
    else
        log_error "Failed to install starship"
        return 1
    fi
}

# Function to setup shell integration
setup_shell_integration() {
    log_info "Setting up shell integration..."

    # Determine shell profile file
    local profile_file
    if [[ "$SHELL" == *"zsh"* ]]; then
        profile_file="$HOME/.zshrc"
    else
        profile_file="$HOME/.bashrc"
    fi

    # Add starship initialization
    if ! grep -q "starship init" "$profile_file"; then
        log_info "Adding starship initialization to $profile_file"
        echo '' >> "$profile_file"
        echo '# Starship prompt' >> "$profile_file"
        echo 'eval "$(starship init zsh)"' >> "$profile_file"
    else
        log_success "✓ Starship initialization already configured"
    fi

    log_success "Shell integration configured"
}

# Function to create starship config directory
setup_starship_config() {
    log_info "Setting up Starship configuration..."

    # Create config directory
    mkdir -p "$HOME/.config"

    # Check if starship config exists
    if [[ -f "$HOME/.config/starship.toml" ]]; then
        log_success "✓ Starship config already exists"
    else
        log_info "Creating basic starship config..."
        cat > "$HOME/.config/starship.toml" << 'EOF'
# Starship prompt configuration
format = """
$username\
$hostname\
$directory\
$git_branch\
$git_status\
$nodejs\
$python\
$rust\
$golang\
$docker_context\
$cmd_duration\
$line_break\
$character"""

[character]
success_symbol = "[➜](bold green)"
error_symbol = "[✗](bold red)"

[directory]
style = "blue bold"
truncation_length = 3
truncation_symbol = "…/"

[git_branch]
symbol = " "
style = "green bold"

[git_status]
style = "red bold"
ahead = "⇡\${count}"
behind = "⇣\${count}"
diverged = "⇕⇡\${ahead_count}⇣\${behind_count}"
untracked = "?"
stashed = "≡"
modified = "!"
staged = "+"
renamed = "»"
deleted = "✘"

[nodejs]
symbol = " "
style = "green bold"

[python]
symbol = " "
style = "yellow bold"

[rust]
symbol = " "
style = "red bold"

[golang]
symbol = " "
style = "cyan bold"

[docker_context]
symbol = " "
style = "blue bold"

[cmd_duration]
min_time = 2000
style = "yellow"

[username]
style_user = "orange bold"
style_root = "red bold"
format = "[$user]($style) "
disabled = false

[hostname]
ssh_only = true
format = "[$hostname](bold red) "
disabled = false
EOF
        log_success "Starship config created"
    fi
}

# Function to test installations
test_installations() {
    log_info "Testing installations..."

    # Test starship
    if command_exists starship; then
        log_success "✓ Starship is working"
        starship --version
    else
        log_error "✗ Starship not found"
    fi

    # Test shell integration
    if grep -q "starship init" "$HOME/.zshrc" 2>/dev/null || grep -q "starship init" "$HOME/.bashrc" 2>/dev/null; then
        log_success "✓ Shell integration configured"
    else
        log_warning "⚠ Shell integration not found"
    fi
}

# Main installation function
main_installation() {
    log_info "=== Cross-platform Starship Installation ==="
    log_info "Detected OS: $OS_NAME ($(uname -s) $(uname -r))"
    log_info "Shell: $SHELL"

    # Install starship
    install_starship

    # Setup configuration
    setup_starship_config
    setup_shell_integration

    # Test installations
    test_installations

    log_success "=== Installation Complete! ==="
    log_info "Please restart your shell or run:"
    log_info "  source ~/.zshrc  # or source ~/.bashrc"
    log_info ""
    log_info "Starship prompt should now be active!"
}

# Run installation
main_installation

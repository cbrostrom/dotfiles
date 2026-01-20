#!/usr/bin/env bash

# Dotfiles Manager with fzf
# Uses fzf for interactive menu selection

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

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
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
    command_exists rg && ((tools_installed++))
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
    if [[ "$OSTYPE" == "darwin"* ]]; then
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

# Function to show fzf menu
show_fzf_menu() {
    # Show status first
    check_install_status
    
    local menu_items=(
        "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        "📦 INSTALLATION"
        "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        "Full Setup [~10-15 min] - Everything: deps, tools, dotfiles, gaming, Cursor"
        "Minimal Setup [~3-5 min] - Basic dotfiles + essential tools only"
        "Custom Components [Interactive] - Pick and choose what to install"
        ""
        "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        "🎯 QUICK ACTIONS"
        "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        "Cursor Settings Sync [~30 sec] - Link Cursor settings to dotfiles"
        "Gaming Launcher [~1 min] - Install gaming scripts and presets"
        "Development Tools [~5-8 min] - Node.js (fnm), modern CLI tools"
        "Platform Configs [~2-3 min] - Ghostty, GNOME, distro-specific"
        ""
        "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        "🔧 MAINTENANCE"
        "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        "Update Setup [~1-2 min] - Refresh symlinks & configs (safe, no reinstall)"
        "Update from Git [~30 sec] - Pull latest dotfiles changes from repository"
        "Check Status [~5 sec] - Show detailed status of all components"
        "Force Update Symlinks [~30 sec] - Recreate all symlinks (fixes broken links)"
        "Reload Shell Config [instant] - Apply changes without restarting terminal"
        ""
        "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        "⚙️  UTILITIES"
        "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        "Preview Installation [~5 sec] - Dry run - see what would be installed"
        "Uninstall Dotfiles [~1 min] - Remove all dotfiles and restore backups"
        "Show Help [instant] - Documentation and usage information"
        "Exit"
    )
    
    # Create menu string
    local menu_string=""
    for item in "${menu_items[@]}"; do
        menu_string+="$item\n"
    done
    
    # Show menu with fzf with better header
    local selection=$(echo -e "$menu_string" | fzf \
        --height 95% \
        --reverse \
        --border \
        --prompt "🔍 Search or select: " \
        --header="Dotfiles Manager v3.0 - Type to search, ↑/↓ to navigate, Enter to select" \
        --header-first \
        --ansi \
        --no-info)
    
    # Handle empty selection (user pressed Ctrl+C or escaped)
    if [[ -z "$selection" ]]; then
        log_info "No selection made. Exiting..."
        exit 0
    fi
    
    # Skip separator lines and empty lines
    if [[ "$selection" == "━"* ]] || [[ "$selection" == "📦"* ]] || [[ "$selection" == "🎯"* ]] || [[ "$selection" == "🔧"* ]] || [[ "$selection" == "⚙️"* ]] || [[ -z "$selection" ]]; then
        show_fzf_menu
        return
    fi
    
    # Extract the action from the selection (before the bracket or dash)
    local action=$(echo "$selection" | sed -E 's/^([^[[-]+).*/\1/' | xargs)
    
    # Handle selection
    case "$action" in
        "Full Setup")
            log_info "Running: Full Setup"
            echo -e "${CYAN}This will install everything: dependencies, tools, dotfiles, gaming, and Cursor settings${NC}"
            run_install "--full"
            ;;
        "Minimal Setup")
            log_info "Running: Minimal Setup"
            echo -e "${CYAN}This will install basic dotfiles and essential tools only${NC}"
            run_install "--minimal"
            ;;
        "Custom Components")
            log_info "Running: Custom Components"
            echo -e "${CYAN}Interactive menu to pick and choose components${NC}"
            run_install "--interactive"
            ;;
        "Cursor Settings Sync")
            log_info "Running: Cursor Settings Sync"
            echo -e "${CYAN}This will create symlinks from Cursor settings to your dotfiles${NC}"
            run_install "--cursor"
            ;;
        "Gaming Launcher")
            log_info "Running: Gaming Launcher"
            echo -e "${CYAN}This will install gaming scripts and presets for Steam${NC}"
            run_install "--gaming"
            ;;
        "Development Tools")
            log_info "Running: Development Tools"
            echo -e "${CYAN}This will install Node.js (via fnm) and modern CLI tools${NC}"
            run_install "--devtools"
            ;;
        "Platform Configs")
            log_info "Running: Platform Configs"
            echo -e "${CYAN}This will install platform-specific configs (Ghostty, GNOME, etc.)${NC}"
            run_install "--platform"
            ;;
        "Update Setup")
            log_info "Running: Update Setup"
            echo -e "${CYAN}This will refresh all symlinks and update configurations${NC}"
            run_install "--update"
            ;;
        "Update from Git")
            log_info "Running: Update from Git"
            echo -e "${CYAN}This will pull the latest changes from your git repository${NC}"
            update_dotfiles
            ;;
        "Check Status")
            log_info "Running: Check Status"
            echo -e "${CYAN}Showing detailed status of all components${NC}"
            run_status
            ;;
        "Force Update Symlinks")
            log_info "Running: Force Update Symlinks"
            echo -e "${CYAN}This will recreate all symlinks (useful if links are broken)${NC}"
            run_force_update_symlinks
            ;;
        "Reload Shell Config")
            log_info "Running: Reload Shell Configuration"
            echo -e "${CYAN}This will reload your shell configuration without restarting${NC}"
            reload_shell_config
            ;;
        "Preview Installation")
            log_info "Running: Preview Installation"
            echo -e "${CYAN}Dry run - showing what would be installed without making changes${NC}"
            run_install "--dry-run"
            ;;
        "Uninstall Dotfiles")
            log_info "Running: Uninstall Dotfiles"
            echo -e "${YELLOW}⚠️  This will remove all dotfiles and restore backups${NC}"
            run_uninstall
            ;;
        "Show Help")
            show_help
            ;;
        "Exit")
            log_info "Exiting..."
            exit 0
            ;;
        *)
            log_error "Unknown selection: '$selection'"
            sleep 2
            show_fzf_menu
            ;;
    esac
}

# Function to install fzf
install_fzf() {
    log_info "fzf not found. Installing it automatically..."
    
    detect_os
    
    if $IS_MACOS; then
        log_info "Installing fzf via Homebrew..."
        if command_exists brew; then
            brew install fzf
            log_success "fzf installed via Homebrew"
        else
            log_error "Homebrew not found. Please install Homebrew first:"
            log_info "  /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
            exit 1
        fi
    elif $IS_LINUX; then
        log_info "Installing fzf via package manager..."
        
        # Try different package managers
        if command_exists apt; then
            sudo apt update && sudo apt install -y fzf
            log_success "fzf installed via apt"
        elif command_exists yum; then
            sudo yum install -y fzf
            log_success "fzf installed via yum"
        elif command_exists dnf; then
            sudo dnf install -y fzf
            log_success "fzf installed via dnf"
        elif command_exists pacman; then
            sudo pacman -S fzf
            log_success "fzf installed via pacman"
        else
            log_error "No supported package manager found. Please install fzf manually:"
            log_info "  Debian/Ubuntu: sudo apt install fzf"
            log_info "  RHEL/CentOS: sudo yum install fzf"
            log_info "  Fedora: sudo dnf install fzf"
            log_info "  Arch: sudo pacman -S fzf"
            exit 1
        fi
    else
        log_error "Unsupported OS. Please install fzf manually:"
        log_info "  Debian/Ubuntu: sudo apt install fzf"
        log_info "  macOS: brew install fzf"
        exit 1
    fi
    
    # Wait a moment for installation to complete
    sleep 1
    
    # Verify installation
    if command_exists fzf; then
        log_success "✓ fzf installed successfully!"
    else
        log_error "fzf installation may have failed. Please install it manually:"
        log_info "  Debian/Ubuntu: sudo apt install fzf"
        log_info "  macOS: brew install fzf"
        exit 1
    fi
}

# Function to show whiptail menu (improved fallback)
show_whiptail_menu() {
    # Show status first
    check_install_status
    echo ""
    
    # Use descriptive menu items
    local menu_items=(
        "Full Setup [10-15min]"
        "Minimal Setup [3-5min]"
        "Custom Components"
        "Cursor Sync [30sec]"
        "Gaming [1min]"
        "Dev Tools [5-8min]"
        "Platform Configs [2-3min]"
        "Update Setup [1-2min]"
        "Update from Git [30sec]"
        "Check Status [5sec]"
        "Force Symlinks [30sec]"
        "Reload Shell [instant]"
        "Preview [5sec]"
        "Uninstall [1min]"
        "Help"
        "Exit"
    )
    
    # Create menu string for whiptail
    local menu_string=""
    local counter=1
    for item in "${menu_items[@]}"; do
        menu_string+="$counter \"$item\" "
        ((counter++))
    done
    
    # Show menu with whiptail
    local selection=$(whiptail --title "Dotfiles Manager v3.0" --menu "Select an option (↑/↓ to navigate):" 24 70 16 $menu_string 3>&1 1>&2 2>&3)
    
    # Handle empty selection (user pressed Cancel or escaped)
    if [[ -z "$selection" ]]; then
        log_info "No selection made. Exiting..."
        exit 0
    fi
    
    # Convert selection number to menu item
    local selected_item="${menu_items[$((selection-1))]}"
    
    # Extract action (before bracket)
    local action=$(echo "$selected_item" | sed -E 's/^([^[]+).*/\1/' | xargs)
    
    # Handle selection
    case "$action" in
        "Full Setup")
            log_info "Running: Full Setup"
            echo -e "${CYAN}Installing everything: dependencies, tools, dotfiles, gaming, Cursor${NC}"
            run_install "--full"
            ;;
        "Minimal Setup")
            log_info "Running: Minimal Setup"
            echo -e "${CYAN}Installing basic dotfiles and essential tools only${NC}"
            run_install "--minimal"
            ;;
        "Custom Components")
            log_info "Running: Custom Components"
            echo -e "${CYAN}Interactive component selection${NC}"
            run_install "--interactive"
            ;;
        "Cursor Sync")
            log_info "Running: Cursor Settings Sync"
            echo -e "${CYAN}Linking Cursor settings to dotfiles${NC}"
            run_install "--cursor"
            ;;
        "Gaming")
            log_info "Running: Gaming Launcher"
            echo -e "${CYAN}Installing gaming scripts and presets${NC}"
            run_install "--gaming"
            ;;
        "Dev Tools")
            log_info "Running: Development Tools"
            echo -e "${CYAN}Installing Node.js and modern CLI tools${NC}"
            run_install "--devtools"
            ;;
        "Platform Configs")
            log_info "Running: Platform Configs"
            echo -e "${CYAN}Installing platform-specific configurations${NC}"
            run_install "--platform"
            ;;
        "Update Setup")
            log_info "Running: Update Setup"
            echo -e "${CYAN}Refreshing symlinks and configurations${NC}"
            run_install "--update"
            ;;
        "Update from Git")
            log_info "Running: Update from Git"
            echo -e "${CYAN}Pulling latest changes from repository${NC}"
            update_dotfiles
            ;;
        "Check Status")
            log_info "Running: Check Status"
            echo -e "${CYAN}Showing component status${NC}"
            run_status
            ;;
        "Force Symlinks")
            log_info "Running: Force Update Symlinks"
            echo -e "${CYAN}Recreating all symlinks${NC}"
            run_force_update_symlinks
            ;;
        "Reload Shell")
            log_info "Running: Reload Shell Configuration"
            echo -e "${CYAN}Reloading shell configuration${NC}"
            reload_shell_config
            ;;
        "Preview")
            log_info "Running: Preview Installation"
            echo -e "${CYAN}Dry run - no changes will be made${NC}"
            run_install "--dry-run"
            ;;
        "Uninstall")
            log_info "Running: Uninstall Dotfiles"
            echo -e "${YELLOW}⚠️  Removing dotfiles and restoring backups${NC}"
            run_uninstall
            ;;
        "Help")
            show_help
            ;;
        "Exit")
            log_info "Exiting..."
            exit 0
            ;;
        *)
            log_error "Unknown selection: '$selected_item'"
            sleep 2
            show_whiptail_menu
            ;;
    esac
}

# Function to run install script
run_install() {
    local args="$1"
    if [[ -f "$SCRIPT_DIR/install.sh" ]]; then
        echo ""
        log_info "Running: ./install.sh $args"
        echo ""
        cd "$SCRIPT_DIR"
        ./install.sh $args
        
        # After installation, show what to do next
        echo ""
        log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        log_success "Installation complete!"
        log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        log_info "Next steps:"
        log_info "  • Run 'dotfiles' to return to this menu"
        log_info "  • Run 'source ~/.zshrc' to reload your shell"
        log_info "  • Or restart your terminal for all changes to take effect"
        echo ""
        read -p "Press Enter to continue..."
    else
        log_error "install.sh not found in $SCRIPT_DIR"
        sleep 2
    fi
}

# Function to run uninstall script
run_uninstall() {
    echo ""
    log_warning "⚠️  WARNING: This will remove all dotfiles and restore backups"
    log_info "This action will:"
    log_info "  • Remove all symlinks created by dotfiles"
    log_info "  • Restore backed up files (if they exist)"
    log_info "  • Keep your dotfiles repository intact"
    echo ""
    read -p "Are you sure you want to continue? (y/N): " -n 1 -r
    echo ""
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Uninstall cancelled"
        sleep 2
        return
    fi
    
    if [[ -f "$SCRIPT_DIR/uninstall.sh" ]]; then
        echo ""
        log_info "Running: ./uninstall.sh"
        echo ""
        cd "$SCRIPT_DIR"
        ./uninstall.sh
        echo ""
        read -p "Press Enter to continue..."
    else
        log_error "uninstall.sh not found in $SCRIPT_DIR"
        sleep 2
    fi
}

# Function to run status script
run_status() {
    if [[ -f "$SCRIPT_DIR/status.sh" ]]; then
        echo ""
        log_info "Running: ./status.sh"
        echo ""
        cd "$SCRIPT_DIR"
        ./status.sh
        echo ""
        read -p "Press Enter to continue..."
    else
        log_error "status.sh not found in $SCRIPT_DIR"
        sleep 2
    fi
}

# Function to run force update symlinks
run_force_update_symlinks() {
    if [[ -f "$SCRIPT_DIR/force-update-symlinks.sh" ]]; then
        echo ""
        log_info "Running: ./force-update-symlinks.sh"
        log_info "This will recreate all symlinks (useful if links are broken)"
        echo ""
        cd "$SCRIPT_DIR"
        ./force-update-symlinks.sh
        echo ""
        log_success "Symlinks updated!"
        read -p "Press Enter to continue..."
    else
        log_error "force-update-symlinks.sh not found in $SCRIPT_DIR"
        sleep 2
    fi
}

# Function to run install missing tools
run_install_missing_tools() {
    if [[ -f "$SCRIPT_DIR/install-missing.sh" ]]; then
        log_info "Running: ./install-missing.sh"
        cd "$SCRIPT_DIR"
        ./install-missing.sh
    else
        log_error "install-missing.sh not found in $SCRIPT_DIR"
    fi
}

# Function to update dotfiles
update_dotfiles() {
    echo ""
    log_info "Updating dotfiles from git repository..."
    log_info "This will pull the latest changes from your remote repository"
    echo ""
    cd "$SCRIPT_DIR"
    
    # Check if we're in a git repository
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        log_error "Not in a git repository"
        sleep 2
        return 1
    fi
    
    # Show current status
    log_info "Current git status:"
    git status --short
    echo ""
    
    # Check for uncommitted changes
    if git status --porcelain | grep -q .; then
        log_warning "⚠️  You have uncommitted changes!"
        log_info "Your changes:"
        git status --short
        echo ""
        log_info "Options:"
        log_info "  1. Commit your changes first: git add . && git commit -m 'message'"
        log_info "  2. Stash your changes: git stash"
        log_info "  3. Cancel this update"
        echo ""
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Update cancelled"
            sleep 2
            return 1
        fi
    fi
    
    # Get the current branch name
    local current_branch=$(git branch --show-current 2>/dev/null || git rev-parse --abbrev-ref HEAD)
    
    # Get the remote name (usually 'origin')
    local remote_name=$(git remote | head -n1)
    if [[ -z "$remote_name" ]]; then
        log_error "No remote repository configured"
        log_info ""
        log_info "To set up a remote repository:"
        log_info "  git remote add origin <your-repo-url>"
        log_info "  git push -u origin $current_branch"
        echo ""
        read -p "Press Enter to continue..."
        return 1
    fi
    
    # Try to pull from the current branch
    log_info "Pulling from $remote_name/$current_branch..."
    echo ""
    if git pull "$remote_name" "$current_branch"; then
        echo ""
        log_success "✓ Dotfiles updated successfully!"
        log_info ""
        log_info "What changed:"
        git log --oneline -5
        echo ""
        log_info "Next steps:"
        log_info "  • Run 'dotfiles' and select 'Update Setup' to refresh symlinks"
        log_info "  • Or run './install.sh --update' directly"
        echo ""
        read -p "Press Enter to continue..."
    else
        echo ""
        log_error "Failed to update dotfiles"
        log_info ""
        log_info "You can try manually:"
        log_info "  cd $SCRIPT_DIR"
        log_info "  git pull $remote_name $current_branch"
        echo ""
        read -p "Press Enter to continue..."
        return 1
    fi
}

# Function to check if shell config was modified
check_shell_config_modified() {
    # Check if .zshrc was modified recently (within last 5 minutes)
    if [[ -f "$HOME/.zshrc" ]]; then
        # Use different stat command based on OS
        local file_age
        if [[ "$OSTYPE" == "darwin"* ]]; then
            # macOS
            file_age=$(( $(date +%s) - $(stat -f %m "$HOME/.zshrc" 2>/dev/null || echo 0) ))
        else
            # Linux
            file_age=$(( $(date +%s) - $(stat -c %Y "$HOME/.zshrc" 2>/dev/null || echo 0) ))
        fi
        
        if [[ $file_age -lt 300 ]]; then  # 5 minutes = 300 seconds
            return 0  # Modified recently
        fi
    fi
    return 1  # Not modified recently
}

# Function to reload shell configuration
reload_shell_config() {
    # Only reload if shell config was actually modified
    if ! check_shell_config_modified; then
        log_info "No shell configuration changes detected."
        return 0
    fi
    
    log_info "Reloading shell configuration..."
    
    # Check if we're in an interactive shell
    if [[ -t 0 ]]; then
        # We're in an interactive shell, suggest reload
        echo
        log_success "✅ Shell configuration updated!"
        log_info "Your dotfiles have been configured successfully."
        log_info "To apply all changes, you can:"
        log_info "  1. Run: source ~/.zshrc"
        log_info "  2. Or restart your terminal session"
        log_info "  3. Or let us reload it for you now"
        echo
        
        # Ask if user wants to reload now
        read -p "🔄 Reload shell configuration now? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            log_info "🔄 Reloading shell configuration..."
            log_info "You should see your new prompt and tools available!"
            exec zsh
        else
            log_info "💡 Remember to run 'source ~/.zshrc' when ready!"
        fi
    else
        # Non-interactive shell, just inform
        log_success "✅ Shell configuration updated!"
        log_info "Run 'source ~/.zshrc' to apply changes."
        log_info "Or restart your terminal session."
    fi
}

# Function to show help
show_help() {
    clear
    cat <<'EOF'
╔════════════════════════════════════════════════════════════════════╗
║                  Dotfiles Manager v3.0 - Help                      ║
╚════════════════════════════════════════════════════════════════════╝

OVERVIEW
--------
Central command center for managing your dotfiles. Provides an interactive
menu with status information and quick actions.

USAGE
-----
  dotfiles              # Run from anywhere (alias configured)
  ./dotfiles.sh         # Run from dotfiles directory

MENU CATEGORIES
---------------

📦 INSTALLATION
  Full Setup           - Complete installation of all components
  Minimal Setup        - Basic dotfiles and essential tools only
  Custom Components    - Interactive selection of specific components

🎯 QUICK ACTIONS
  Cursor Settings Sync - Link Cursor settings/keybindings to dotfiles
  Gaming Launcher      - Install gaming scripts for Steam
  Development Tools    - Install Node.js (fnm) and modern CLI tools
  Platform Configs     - Install OS-specific configurations

🔧 MAINTENANCE
  Update Setup         - Refresh symlinks and configs (safe, no reinstall)
  Update from Git      - Pull latest dotfiles from repository
  Check Status         - Show detailed status of all components
  Force Update Symlinks- Recreate all symlinks (fixes broken links)
  Reload Shell Config  - Apply changes without restarting terminal

⚙️  UTILITIES
  Preview Installation - Dry run to see what would be installed
  Uninstall Dotfiles   - Remove all dotfiles and restore backups
  Show Help            - This help screen

STATUS INDICATORS
-----------------
  ✓ (green)  - Fully installed and configured
  ◐ (yellow) - Partially installed or needs attention
  ✗ (red)    - Not installed

REQUIREMENTS
------------
  - fzf (preferred) or whiptail (fallback) for interactive menu
  - git for version control
  - zsh as shell (will be installed if needed)

TIPS
----
  • Run "dotfiles" from anywhere to access this menu
  • Use "Check Status" to see what's installed
  • Use "Update Setup" after pulling git changes
  • Time estimates help you plan when to run installations

TROUBLESHOOTING
---------------
  • If symlinks are broken: Use "Force Update Symlinks"
  • If shell changes don't apply: Use "Reload Shell Config"
  • If components are missing: Use "Check Status" first
  • For fresh start: Use "Uninstall" then "Full Setup"

Press Enter to return to menu...
EOF
    read -r
    show_system_info
    if command_exists fzf; then
        show_fzf_menu
    else
        show_whiptail_menu
    fi
}

# Function to show system info
show_system_info() {
    clear
    cat <<'EOF'
╔════════════════════════════════════════════════════════════════════╗
║                      Dotfiles Manager v3.0                         ║
╚════════════════════════════════════════════════════════════════════╝

EOF
    echo -e "${BLUE}System Information:${NC}"
    echo -e "  OS: $(uname -s) $(uname -r)"
    echo -e "  Shell: $SHELL"
    echo -e "  Dotfiles: $SCRIPT_DIR"
    echo ""
}

# Function to detect OS
detect_os() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        OS_NAME="macOS"
        IS_MACOS=true
        IS_LINUX=false
    elif [[ "$OSTYPE" == "linux-gnu"* ]] || [[ "$OSTYPE" == "linux"* ]]; then
        OS_NAME="Linux"
        IS_MACOS=false
        IS_LINUX=true
        # Check for WSL
        if grep -q Microsoft /proc/version 2>/dev/null; then
            OS_NAME="WSL2"
        fi
    else
        OS_NAME="Unknown"
        IS_MACOS=false
        IS_LINUX=false
    fi
}



# Main function
main() {
    # Show system info
    show_system_info
    
    # Check if fzf is available, offer to install if not
    if ! command_exists fzf; then
        log_warning "fzf is not installed."
        echo
        log_info "Would you like to install fzf automatically? (y/N)"
        read -p "Press 'y' to auto-install, or any other key to continue with fallback: " -n 1 -r
        echo
        
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            install_fzf
        fi
    fi
    
    # Try fzf first (preferred), then whiptail as fallback
    if command_exists fzf; then
        log_info "Using fzf for menu selection"
        show_fzf_menu
    elif command_exists whiptail; then
        log_info "Using whiptail for menu selection (fzf not available)"
        show_whiptail_menu
    else
        log_error "Neither fzf nor whiptail is available. Please install one:"
        log_info "  Debian/Ubuntu: sudo apt install fzf"
        log_info "  macOS: brew install fzf"
        log_info "  Or whiptail is usually pre-installed on most systems"
        exit 1
    fi
}

# Run main function
main "$@"

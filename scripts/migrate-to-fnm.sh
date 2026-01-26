#!/usr/bin/env bash

# Migration script: asdf -> fnm for Node.js management
# This script helps migrate from asdf to fnm for better .nvmrc support

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

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to backup current Node.js setup
backup_current_setup() {
    log_info "Creating backup of current Node.js setup..."
    
    # Backup current Node.js version
    if command_exists node; then
        local current_version=$(node --version 2>/dev/null || echo "unknown")
        echo "$current_version" > /tmp/node_version_backup.txt
        log_success "Backed up current Node.js version: $current_version"
    fi
    
    # Backup asdf Node.js versions
    if command_exists asdf; then
        log_info "Backing up asdf Node.js versions..."
        asdf list nodejs > /tmp/asdf_nodejs_versions.txt 2>/dev/null || true
        log_success "Backed up asdf Node.js versions"
    fi
}

# Function to install fnm
install_fnm() {
    log_info "Installing fnm (Fast Node Manager)..."
    
    if command_exists fnm; then
        log_success "✓ fnm already installed"
        return 0
    fi
    
    # Detect OS
    if [[ "$OSTYPE" == "darwin"* ]]; then
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
    
    log_success "fnm installed successfully"
}

# Function to migrate Node.js versions
migrate_node_versions() {
    log_info "Migrating Node.js versions from asdf to fnm..."
    
    # Source fnm
    export PATH="$HOME/.local/share/fnm:$PATH"
    eval "$(fnm env --use-on-cd)"
    
    # Install LTS version as default
    log_info "Installing Node.js LTS..."
    fnm install --lts
    fnm use --lts
    fnm default --lts
    
    # If we have asdf Node.js versions, try to install them in fnm
    if [[ -f /tmp/asdf_nodejs_versions.txt ]]; then
        log_info "Installing additional Node.js versions from asdf backup..."
        while IFS= read -r version; do
            if [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                log_info "Installing Node.js $version..."
                fnm install "$version" 2>/dev/null || log_warning "Failed to install Node.js $version"
            fi
        done < /tmp/asdf_nodejs_versions.txt
    fi
    
    log_success "Node.js versions migrated to fnm"
}

# Function to update shell configuration
update_shell_config() {
    log_info "Updating shell configuration for fnm..."
    
    local profile_file="$HOME/.zshrc"
    
    # Add fnm configuration if not already present
    if ! grep -q "fnm env" "$profile_file"; then
        log_info "Adding fnm configuration to $profile_file..."
        echo '' >> "$profile_file"
        echo '# fnm (Fast Node Manager) for Node.js with .nvmrc support' >> "$profile_file"
        echo 'eval "$(fnm env --use-on-cd)"' >> "$profile_file"
        echo 'alias nvm="fnm"  # Alias for compatibility' >> "$profile_file"
        log_success "fnm configuration added to $profile_file"
    else
        log_success "✓ fnm configuration already present in $profile_file"
    fi
}

# Function to remove asdf Node.js plugin
remove_asdf_nodejs() {
    log_info "Removing asdf Node.js plugin..."
    
    if command_exists asdf; then
        # Check if nodejs plugin is installed
        if asdf plugin list | grep -q "nodejs"; then
            log_warning "Removing asdf nodejs plugin..."
            asdf plugin remove nodejs
            log_success "asdf nodejs plugin removed"
        else
            log_success "✓ asdf nodejs plugin not found"
        fi
    else
        log_warning "asdf not found, skipping nodejs plugin removal"
    fi
}

# Function to test fnm setup
test_fnm_setup() {
    log_info "Testing fnm setup..."
    
    # Source fnm
    export PATH="$HOME/.local/share/fnm:$PATH"
    eval "$(fnm env --use-on-cd)"
    
    # Test basic functionality
    if fnm --version >/dev/null 2>&1; then
        log_success "✓ fnm is working correctly"
    else
        log_error "❌ fnm is not working correctly"
        return 1
    fi
    
    # Test Node.js installation
    if command_exists node; then
        local node_version=$(node --version)
        log_success "✓ Node.js is available: $node_version"
    else
        log_error "❌ Node.js is not available"
        return 1
    fi
    
    # Test .nvmrc support
    log_info "Testing .nvmrc support..."
    local test_dir="/tmp/fnm_test"
    mkdir -p "$test_dir"
    cd "$test_dir"
    
    echo "18.17.0" > .nvmrc
    fnm use
    local used_version=$(node --version)
    log_success "✓ .nvmrc support working: $used_version"
    
    # Cleanup
    cd /
    rm -rf "$test_dir"
}

# Function to show help
show_help() {
    cat <<'EOF'
Migration Script: asdf -> fnm for Node.js

This script helps migrate from asdf to fnm for better .nvmrc support.

Usage: ./migrate-to-fnm.sh [OPTIONS]

Options:
  --help, -h          Show this help message
  --backup-only       Only create backup, don't migrate
  --test-only         Only test fnm setup
  --force             Force migration even if fnm is already installed

What this script does:
1. Creates backup of current Node.js setup
2. Installs fnm (Fast Node Manager)
3. Migrates Node.js versions from asdf to fnm
4. Updates shell configuration
5. Removes asdf Node.js plugin
6. Tests the new setup

Benefits of fnm over asdf for Node.js:
- Better .nvmrc support
- Faster performance
- Automatic version switching
- Better compatibility with existing Node.js workflows
- nvm alias for seamless transition

EOF
}

# Main function
main() {
    local backup_only=false
    local test_only=false
    local force=false
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --help|-h)
                show_help
                exit 0
                ;;
            --backup-only)
                backup_only=true
                shift
                ;;
            --test-only)
                test_only=true
                shift
                ;;
            --force)
                force=true
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    log_info "=== Migration Script: asdf -> fnm for Node.js ==="
    
    if $test_only; then
        test_fnm_setup
        exit 0
    fi
    
    # Create backup
    backup_current_setup
    
    if $backup_only; then
        log_success "Backup completed. Run without --backup-only to perform migration."
        exit 0
    fi
    
    # Install fnm
    install_fnm
    
    # Migrate Node.js versions
    migrate_node_versions
    
    # Update shell configuration
    update_shell_config
    
    # Remove asdf Node.js plugin
    remove_asdf_nodejs
    
    # Test the setup
    test_fnm_setup
    
    log_success "=== Migration Complete! ==="
    log_info ""
    log_info "Next steps:"
    log_info "1. Restart your terminal or run: source ~/.zshrc"
    log_info "2. Test .nvmrc files in your projects"
    log_info "3. Use 'fnm install <version>' to install new Node.js versions"
    log_info "4. Use 'fnm use <version>' to switch versions"
    log_info "5. Use 'fnm default <version>' to set default version"
    log_info ""
    log_info "fnm commands:"
    log_info "  fnm install --lts          # Install latest LTS"
    log_info "  fnm install 18.17.0        # Install specific version"
    log_info "  fnm use 18.17.0            # Use specific version"
    log_info "  fnm list                   # List installed versions"
    log_info "  fnm default 18.17.0        # Set default version"
    log_info ""
    log_info "nvm alias is also available:"
    log_info "  nvm install --lts          # Same as fnm install --lts"
    log_info "  nvm use 18.17.0            # Same as fnm use 18.17.0"
    log_info ""
    log_info "Your .nvmrc files will now work automatically!"
}

# Run main function
main "$@" 
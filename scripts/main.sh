#!/bin/bash

# Dotfiles Main Menu
# Unified interface for all dotfiles management operations

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DOTFILES_SCRIPT="$SCRIPT_DIR/scripts/dotfiles.sh"
VERSION_SCRIPT="$SCRIPT_DIR/scripts/version.sh"

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

show_header() {
    echo -e "\n${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                    DOTFILES MANAGER                           ║${NC}"
    echo -e "${CYAN}║                    Complete Control Center                    ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
}

show_main_menu() {
    echo -e "\n${BLUE}📁 DOTFILES MANAGEMENT${NC}"
    echo "========================"
    echo "1. Install dotfiles"
    echo "2. List dotfiles status"
    echo "3. Uninstall dotfiles"
    echo "4. Initialize configuration"
    echo "5. Update dotfiles (pull + reinstall)"
    echo ""
    echo -e "${MAGENTA}🏷️  VERSION MANAGEMENT${NC}"
    echo "========================"
    echo "6. Show current version"
    echo "7. Bump version"
    echo "8. Git status"
    echo "9. Quick update (add + commit + push)"
    echo "10. Full release workflow"
    echo ""
    echo -e "${YELLOW}⚙️  UTILITIES${NC}"
    echo "============="
    echo "11. Show help"
    echo "12. Open version manager menu"
    echo "13. Open dotfiles manager menu"
    echo ""
    echo "0. Exit"
    echo ""
}

show_bump_menu() {
    echo -e "\n${BLUE}Bump Version${NC}"
    echo "============="
    echo "1. Major (breaking changes)"
    echo "2. Minor (new features)"
    echo "3. Patch (bug fixes)"
    echo "0. Back"
    echo ""
}

get_bump_type() {
    local choice="$1"
    case $choice in
    1) echo "major" ;;
    2) echo "minor" ;;
    3) echo "patch" ;;
    *) echo "" ;;
    esac
}

install_dotfiles() {
    log_info "Installing dotfiles..."
    "$DOTFILES_SCRIPT" install
}

list_dotfiles() {
    log_info "Showing dotfiles status..."
    "$DOTFILES_SCRIPT" list
}

uninstall_dotfiles() {
    log_info "Uninstalling dotfiles..."
    "$DOTFILES_SCRIPT" uninstall
}

init_config() {
    log_info "Initializing configuration..."
    "$DOTFILES_SCRIPT" init
}

update_dotfiles() {
    log_info "Updating dotfiles from remote..."

    # Check if we have uncommitted changes
    if ! git diff-index --quiet HEAD --; then
        log_warning "You have uncommitted changes. Stashing them..."
        git stash push -m "Auto-stash before update $(date)"
    fi

    # Pull latest changes
    log_info "Pulling latest changes from remote..."
    if git pull origin master; then
        log_success "Successfully pulled latest changes"

        # Reinstall dotfiles to apply any new configurations
        log_info "Reinstalling dotfiles with latest changes..."
        "$DOTFILES_SCRIPT" install

        # Restore stashed changes if any
        if git stash list | grep -q "Auto-stash before update"; then
            log_info "Restoring stashed changes..."
            git stash pop
        fi

        log_success "Dotfiles updated successfully!"
    else
        log_error "Failed to pull latest changes"
        return 1
    fi
}

show_version() {
    log_info "Current version:"
    "$VERSION_SCRIPT" status
}

bump_version() {
    show_bump_menu
    read -p "Select bump type: " bump_choice

    local bump_type=$(get_bump_type "$bump_choice")
    if [[ -n "$bump_type" ]]; then
        log_info "Bumping $bump_type version..."
        "$VERSION_SCRIPT" bump "$bump_type"
    else
        log_warning "No bump type selected"
    fi
}

git_status() {
    log_info "Git status:"
    "$VERSION_SCRIPT" status
}

quick_update() {
    log_info "Quick update workflow..."
    "$VERSION_SCRIPT" quick
}

full_release() {
    log_info "Full release workflow..."
    "$VERSION_SCRIPT" release
}

show_help() {
    cat <<EOF

${CYAN}Dotfiles Manager - Complete Control Center${NC}

${BLUE}📁 DOTFILES MANAGEMENT${NC}
=======================
install    - Install/symlink all dotfiles
list       - Show status of all dotfiles
uninstall  - Remove all symlinks
init       - Initialize configuration file
update     - Pull latest changes and reinstall

${MAGENTA}🏷️  VERSION MANAGEMENT${NC}
=======================
version    - Show current version
bump       - Bump version (major/minor/patch)
status     - Show git status
quick      - Quick update (add + commit + push)
release    - Full release workflow

${YELLOW}⚙️  UTILITIES${NC}
=============
help       - Show this help
menu       - Open interactive menu

${GREEN}Examples:${NC}
  dotfiles install
  dotfiles list
  dotfiles update
  dotfiles quick
  dotfiles release

EOF
}

open_version_menu() {
    log_info "Opening version manager menu..."
    "$VERSION_SCRIPT"
}

open_dotfiles_menu() {
    log_info "Opening dotfiles manager menu..."
    "$DOTFILES_SCRIPT"
}

main() {
    cd "$SCRIPT_DIR"

    # Check if we're in a git repo
    if ! git rev-parse --git-dir >/dev/null 2>&1; then
        log_error "Not in a git repository"
        exit 1
    fi

    while true; do
        show_header
        show_main_menu
        read -p "Select option: " choice

        case $choice in
        1)
            install_dotfiles
            ;;
        2)
            list_dotfiles
            ;;
        3)
            uninstall_dotfiles
            ;;
        4)
            init_config
            ;;
        5)
            update_dotfiles
            ;;
        6)
            show_version
            ;;
        7)
            bump_version
            ;;
        8)
            git_status
            ;;
        9)
            quick_update
            ;;
        10)
            full_release
            ;;
        11)
            show_help
            ;;
        12)
            open_version_menu
            ;;
        13)
            open_dotfiles_menu
            ;;
        0)
            log_info "Goodbye!"
            exit 0
            ;;
        *)
            log_error "Invalid option: $choice"
            ;;
        esac

        echo ""
        read -p "Press Enter to continue..."
    done
}

# Handle command line arguments
if [[ $# -gt 0 ]]; then
    case $1 in
    install)
        install_dotfiles
        ;;
    list | l)
        list_dotfiles
        ;;
    uninstall | u)
        uninstall_dotfiles
        ;;
    init)
        init_config
        ;;
    update)
        update_dotfiles
        ;;
    version)
        show_version
        ;;
    bump)
        if [[ -z "$2" ]]; then
            log_error "Usage: $0 bump <major|minor|patch>"
            exit 1
        fi
        "$VERSION_SCRIPT" bump "$2"
        ;;
    status)
        git_status
        ;;
    quick)
        quick_update
        ;;
    release)
        full_release
        ;;
    help | h | --help)
        show_help
        ;;
    menu)
        main
        ;;
    *)
        log_error "Unknown command: $1"
        echo "Use '$0 help' for available commands"
        exit 1
        ;;
    esac
else
    main
fi

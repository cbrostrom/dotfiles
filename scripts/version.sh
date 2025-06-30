#!/bin/bash

# Version Management Script
# Handles versioning, git operations, and releases

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Cross-platform path detection
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
VERSION_FILE="$DOTFILES_ROOT/VERSION"

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

get_current_version() {
    if [[ -f "$VERSION_FILE" ]]; then
        cat "$VERSION_FILE"
    else
        echo "0.0.0"
    fi
}

update_version() {
    local version="$1"
    echo "$version" >"$VERSION_FILE"
    log_success "Updated version to $version"
}

bump_version() {
    local current_version=$(get_current_version)
    local bump_type="$1"

    IFS='.' read -ra VERSION_PARTS <<<"$current_version"
    local major="${VERSION_PARTS[0]}"
    local minor="${VERSION_PARTS[1]}"
    local patch="${VERSION_PARTS[2]}"

    case $bump_type in
    major)
        major=$((major + 1))
        minor=0
        patch=0
        ;;
    minor)
        minor=$((minor + 1))
        patch=0
        ;;
    patch)
        patch=$((patch + 1))
        ;;
    *)
        log_error "Invalid bump type: $bump_type"
        exit 1
        ;;
    esac

    local new_version="$major.$minor.$patch"
    update_version "$new_version"
    echo "$new_version"
}

git_status() {
    log_info "Git status:"
    git status --short
}

git_add_all() {
    log_info "Adding all changes..."
    git add .
    log_success "All changes staged"
}

git_commit() {
    local message="$1"
    if [[ -z "$message" ]]; then
        message="Update dotfiles $(get_current_version)"
    fi

    log_info "Committing with message: $message"
    git commit -m "$message"
    log_success "Changes committed"
}

git_tag() {
    local version="$1"
    local tag_message="Version $version"

    log_info "Creating tag v$version"
    git tag -a "v$version" -m "$tag_message"
    log_success "Tag v$version created"
}

git_push() {
    local push_tags="$1"

    log_info "Pushing to remote..."
    git push

    if [[ "$push_tags" == "true" ]]; then
        log_info "Pushing tags..."
        git push --tags
    fi

    log_success "Pushed to remote"
}

show_menu() {
    echo -e "\n${BLUE}Dotfiles Version Manager${NC}"
    echo "========================"
    echo "1. Show current version"
    echo "2. Bump version (major/minor/patch)"
    echo "3. Show git status"
    echo "4. Add all changes"
    echo "5. Commit changes"
    echo "6. Create tag"
    echo "7. Push to remote"
    echo "8. Full release workflow"
    echo "9. Quick update (add + commit + push)"
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

full_release_workflow() {
    local current_version=$(get_current_version)
    log_info "Starting full release workflow..."

    # Show current status
    git_status

    # Ask for bump type
    show_bump_menu
    read -p "Select bump type: " bump_choice

    local bump_type=$(get_bump_type "$bump_choice")
    if [[ -z "$bump_type" ]]; then
        log_warning "No bump type selected, skipping version bump"
        return
    fi

    # Bump version
    local new_version=$(bump_version "$bump_type")

    # Add all changes
    git_add_all

    # Commit
    git_commit "Release version $new_version"

    # Create tag
    git_tag "$new_version"

    # Push
    git_push "true"

    log_success "Release $new_version completed!"
}

quick_update() {
    log_info "Quick update workflow..."

    git_add_all
    git_commit
    git_push "false"

    log_success "Quick update completed!"
}

main() {
    cd "$SCRIPT_DIR"

    # Check if we're in a git repo
    if ! git rev-parse --git-dir >/dev/null 2>&1; then
        log_error "Not in a git repository"
        exit 1
    fi

    # Change to dotfiles root directory for git operations
    cd "$DOTFILES_ROOT"

    while true; do
        show_menu
        read -p "Select option: " choice

        case $choice in
        1)
            log_info "Current version: $(get_current_version)"
            ;;
        2)
            show_bump_menu
            read -p "Select bump type: " bump_choice
            bump_type=$(get_bump_type "$bump_choice")
            if [[ -n "$bump_type" ]]; then
                bump_version "$bump_type"
            fi
            ;;
        3)
            git_status
            ;;
        4)
            git_add_all
            ;;
        5)
            read -p "Commit message (optional): " commit_message
            git_commit "$commit_message"
            ;;
        6)
            local version=$(get_current_version)
            git_tag "$version"
            ;;
        7)
            read -p "Push tags? (y/N): " push_tags
            if [[ "$push_tags" =~ ^[Yy]$ ]]; then
                git_push "true"
            else
                git_push "false"
            fi
            ;;
        8)
            full_release_workflow
            ;;
        9)
            quick_update
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
    status)
        cd "$SCRIPT_DIR"
        git_status
        ;;
    bump)
        if [[ -z "$2" ]]; then
            log_error "Usage: $0 bump <major|minor|patch>"
            exit 1
        fi
        cd "$SCRIPT_DIR"
        bump_version "$2"
        ;;
    release)
        cd "$SCRIPT_DIR"
        full_release_workflow
        ;;
    quick)
        cd "$SCRIPT_DIR"
        quick_update
        ;;
    *)
        log_error "Unknown command: $1"
        echo "Usage: $0 [status|bump <type>|release|quick]"
        exit 1
        ;;
    esac
else
    main
fi

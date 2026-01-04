# =============================================================================
# FUNCTIONS
# =============================================================================
# Utility functions and custom commands

# =============================================================================
# DOTFILES FUNCTION
# =============================================================================
# Function to find and run dotfiles manager from anywhere
dotfiles() {
    # Try to find dotfiles.sh in common locations
    local dotfiles_path=""

    # Check if we're in a dotfiles directory
    if [[ -f "./dotfiles.sh" ]]; then
        dotfiles_path="./dotfiles.sh"
    # Check common installation paths
    elif [[ -f "$HOME/dotfiles/dotfiles.sh" ]]; then
        dotfiles_path="$HOME/dotfiles/dotfiles.sh"
    elif [[ -f "$HOME/.dotfiles/dotfiles.sh" ]]; then
        dotfiles_path="$HOME/.dotfiles/dotfiles.sh"
    # Search in git repositories
    elif command -v git >/dev/null 2>&1; then
        # Find git root and check for dotfiles.sh
        local git_root=$(git rev-parse --show-toplevel 2>/dev/null)
        if [[ -n "$git_root" ]] && [[ -f "$git_root/dotfiles.sh" ]]; then
            dotfiles_path="$git_root/dotfiles.sh"
        fi
    fi

    if [[ -n "$dotfiles_path" ]]; then
        "$dotfiles_path" "$@"
    else
        echo "Error: dotfiles.sh not found"
        echo "Please ensure you're in a dotfiles directory or have dotfiles installed in ~/dotfiles or ~/.dotfiles"
        return 1
    fi
}

# =============================================================================
# PORT UTILITIES
# =============================================================================
# Load utility functions for managing ports
if [[ -f "$HOME/dotfiles/functions/port-utils.sh" ]]; then
    source "$HOME/dotfiles/functions/port-utils.sh"
fi


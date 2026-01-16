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
    elif [[ -f "$HOME/.config/dotfiles/dotfiles.sh" ]]; then
        dotfiles_path="$HOME/.config/dotfiles/dotfiles.sh"
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
        echo "Please ensure you're in a dotfiles directory or have dotfiles installed"
        echo "Searched: ~/.config/dotfiles, ~/dotfiles, ~/.dotfiles"
        return 1
    fi
}

# =============================================================================
# PORT UTILITIES
# =============================================================================
# Load utility functions for managing ports
if [[ -f "$HOME/dotfiles/functions/port-utils.sh" ]]; then
    source "$HOME/dotfiles/functions/port-utils.sh"
elif [[ -f "$HOME/.config/dotfiles/functions/port-utils.sh" ]]; then
    source "$HOME/.config/dotfiles/functions/port-utils.sh"
fi

# =============================================================================
# CUSTOM UTILITY FUNCTIONS
# =============================================================================

# mkcd - Create directory and cd into it
mkcd() {
    if [ $# -ne 1 ]; then
        echo "Usage: mkcd <directory>"
        return 1
    fi
    mkdir -p "$1" && cd "$1"
}

# extract - Universal archive extractor
extract() {
    if [ -f "$1" ]; then
        case "$1" in
            *.tar.bz2)   tar xjf "$1"     ;;
            *.tar.gz)    tar xzf "$1"     ;;
            *.bz2)       bunzip2 "$1"     ;;
            *.rar)       unrar x "$1"     ;;
            *.gz)        gunzip "$1"      ;;
            *.tar)       tar xf "$1"      ;;
            *.tbz2)      tar xjf "$1"     ;;
            *.tgz)       tar xzf "$1"     ;;
            *.zip)       unzip "$1"       ;;
            *.Z)         uncompress "$1"  ;;
            *.7z)        7z x "$1"        ;;
            *.tar.xz)    tar xf "$1"      ;;
            *.txz)       tar xf "$1"      ;;
            *)           echo "'$1' cannot be extracted via extract()" ;;
        esac
    else
        echo "'$1' is not a valid file"
    fi
}

# backup - Quick file backup with timestamp
backup() {
    if [ $# -ne 1 ]; then
        echo "Usage: backup <file>"
        return 1
    fi
    
    if [ ! -e "$1" ]; then
        echo "Error: '$1' does not exist"
        return 1
    fi
    
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_name="${1}.backup_${timestamp}"
    
    cp -r "$1" "$backup_name"
    echo "Backup created: $backup_name"
}

# Code search with context (uses ripgrep if available)
codeSearch() {
    if [ $# -lt 1 ]; then
        echo "Usage: codeSearch <pattern> [path]"
        return 1
    fi
    
    local pattern="$1"
    local search_path="${2:-.}"
    
    if command -v rg &>/dev/null; then
        rg --color=always --context 3 --line-number "$pattern" "$search_path"
    else
        grep -r -n --color=always "$pattern" "$search_path"
    fi
}

# Git clone and cd into directory
gcl() {
    if [ $# -eq 0 ]; then
        echo "Usage: gcl <repository_url>"
        return 1
    fi
    
    git clone "$@" && cd "$(basename "$1" .git)"
}

# Find and kill process by name
killport() {
    if [ $# -ne 1 ]; then
        echo "Usage: killport <port>"
        return 1
    fi
    
    local pid=$(lsof -ti:$1)
    if [ -n "$pid" ]; then
        echo "Killing process $pid on port $1"
        kill -9 $pid
    else
        echo "No process found on port $1"
    fi
}

# Quick server for current directory
serve() {
    local port="${1:-8000}"
    echo "Starting server on http://localhost:$port"
    
    if command -v python3 &>/dev/null; then
        python3 -m http.server "$port"
    elif command -v python &>/dev/null; then
        python -m SimpleHTTPServer "$port"
    else
        echo "Python not found. Install python3 to use this function."
        return 1
    fi
}

# Weather function (using wttr.in)
weather() {
    local location="${1:-}"
    curl "wttr.in/${location}"
}



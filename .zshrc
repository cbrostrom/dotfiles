# =============================================================================
# MODULAR ZSH CONFIGURATION
# =============================================================================
# This is a clean, modular zsh configuration that loads separate modules
# for better organization and maintainability.
#
# Structure:
#   01-environment.zsh  - OS detection, terminal setup, PATH, environment vars
#   02-plugins.zsh      - zinit, FZF, completions, zoxide, starship, fnm
#   03-aliases.zsh      - Modern tool replacements and shortcuts
#   04-functions.zsh    - Custom functions and utilities
#   05-integrations.zsh - Editor integrations (Cursor, VS Code)
#
# All modules are stored in: ~/dotfiles/zsh/
# =============================================================================

# Determine the dotfiles directory
# This works whether .zshrc is sourced directly or via symlink
if [[ -L "${(%):-%N}" ]]; then
    # .zshrc is a symlink, get the actual file location
    DOTFILES_DIR="$(cd "$(dirname "$(readlink "${(%):-%N}")")" && pwd)"
else
    # .zshrc is a regular file in the dotfiles directory
    DOTFILES_DIR="$(cd "$(dirname "${(%):-%N}")" && pwd)"
fi

# If we're in the home directory, assume dotfiles is in ~/dotfiles
if [[ "$DOTFILES_DIR" == "$HOME" ]]; then
    DOTFILES_DIR="$HOME/dotfiles"
fi

ZSH_MODULES_DIR="$DOTFILES_DIR/zsh"

# =============================================================================
# LOAD MODULES
# =============================================================================
# Load each module in order
# Modules are loaded only if they exist to prevent errors

if [[ -d "$ZSH_MODULES_DIR" ]]; then
    # 01 - Environment (OS detection, PATH, terminal)
    [[ -f "$ZSH_MODULES_DIR/01-environment.zsh" ]] && source "$ZSH_MODULES_DIR/01-environment.zsh"
    
    # 02 - Plugins (zinit, FZF, completions, zoxide, starship, fnm)
    [[ -f "$ZSH_MODULES_DIR/02-plugins.zsh" ]] && source "$ZSH_MODULES_DIR/02-plugins.zsh"
    
    # 03 - Aliases (modern tool replacements)
    [[ -f "$ZSH_MODULES_DIR/03-aliases.zsh" ]] && source "$ZSH_MODULES_DIR/03-aliases.zsh"
    
    # 04 - Functions (custom utilities)
    [[ -f "$ZSH_MODULES_DIR/04-functions.zsh" ]] && source "$ZSH_MODULES_DIR/04-functions.zsh"
    
    # 05 - Integrations (editor integrations)
    [[ -f "$ZSH_MODULES_DIR/05-integrations.zsh" ]] && source "$ZSH_MODULES_DIR/05-integrations.zsh"
else
    echo "Warning: ZSH modules directory not found at $ZSH_MODULES_DIR"
    echo "Falling back to basic configuration"
    
    # Minimal fallback configuration
    export PATH="$HOME/.local/bin:$PATH"
    
    # Load starship if available
    if command -v starship &>/dev/null; then
        eval "$(starship init zsh)"
    fi
fi

# =============================================================================
# MACHINE-SPECIFIC CONFIGURATION (Optional)
# =============================================================================
# Load machine-specific configuration if it exists
# This file is not tracked in git and can contain local customizations
if [[ -f "$HOME/.zshrc.local" ]]; then
    source "$HOME/.zshrc.local"
fi

# =============================================================================
# PERFORMANCE PROFILING (Optional)
# =============================================================================
# Uncomment to enable zsh startup profiling
# To use: Add 'zmodload zsh/zprof' to the top of this file
# Then run 'zprof' after shell startup to see timing report
# [[ -n "$ZPROF" ]] && zprof


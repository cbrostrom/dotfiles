#!/usr/bin/env bash
# Install script for dotfiles symlinks
# Creates symlinks for all dotfiles and config directories
# Cross-platform compatible: macOS, Linux, WSL2

set -e

# OS Detection
if [[ "$OSTYPE" == "darwin"* ]]; then
    IS_MACOS=true
    IS_LINUX=false
elif [[ "$OSTYPE" == "linux-gnu"* ]] || [[ "$OSTYPE" == "linux"* ]]; then
    IS_MACOS=false
    IS_LINUX=true
    # Check for WSL
    if grep -q Microsoft /proc/version 2>/dev/null; then
        IS_WSL=true
    else
        IS_WSL=false
    fi
else
    IS_MACOS=false
    IS_LINUX=false
    IS_WSL=false
fi

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

# Get script directory (cross-platform)
# Script is in scripts/install/, dotfiles root is two levels up
if [[ -n "$BASH_SOURCE" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
else
    SCRIPT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
fi

# Function to create symlink with backup
create_symlink() {
    local source="$1"
    local target="$2"
    local description="$3"

    if [[ ! -e "$source" ]]; then
        log_warning "Source not found, skipping: $source"
        return 0
    fi

    # Create target directory if it doesn't exist
    local target_dir="$(dirname "$target")"
    if [[ ! -d "$target_dir" ]]; then
        log_info "Creating directory: $target_dir"
        mkdir -p "$target_dir"
    fi

    # Handle existing target
    if [[ -L "$target" ]]; then
        log_info "Removing existing symlink: $target"
        rm "$target"
    elif [[ -e "$target" ]]; then
        local backup="$target.backup.$(date +%Y%m%d_%H%M%S)"
        log_warning "Backing up existing file: $target -> $backup"
        mv "$target" "$backup"
    fi

    # Create relative symlink (cross-platform)
    local rel_source
    if command -v realpath >/dev/null 2>&1; then
        rel_source=$(realpath --relative-to="$(dirname "$target")" "$source" 2>/dev/null || echo "$source")
    elif command -v python3 >/dev/null 2>&1; then
        # Fallback using Python for relative path calculation
        rel_source=$(python3 -c "import os.path; print(os.path.relpath('$source', os.path.dirname('$target')))" 2>/dev/null || echo "$source")
    elif command -v node >/dev/null 2>&1; then
        # Fallback using Node.js
        rel_source=$(node -e "const path = require('path'); console.log(path.relative(path.dirname('$target'), '$source'))" 2>/dev/null || echo "$source")
    else
        # Final fallback - use absolute path
        rel_source="$source"
        log_warning "Using absolute path for symlink (install realpath, python3, or node for relative paths)"
    fi

    # Create symlink
    log_info "Creating symlink: $description"
    ln -sf "$rel_source" "$target"
    log_success "Created symlink: $target -> $rel_source"
}

# Main installation
log_info "Installing dotfiles symlinks..."
log_info "Detected OS: $(uname -s) $(uname -r)"

# Basic dotfiles
create_symlink "$SCRIPT_DIR/.zshrc" "$HOME/.zshrc" ".zshrc"
create_symlink "$SCRIPT_DIR/.zshenv" "$HOME/.zshenv" ".zshenv"
create_symlink "$SCRIPT_DIR/.gitconfig" "$HOME/.gitconfig" ".gitconfig"
create_symlink "$SCRIPT_DIR/.gitignore_global" "$HOME/.gitignore_global" ".gitignore_global"
create_symlink "$SCRIPT_DIR/.tmux.conf" "$HOME/.tmux.conf" "tmux config"

# Per-machine git overrides (signing keys etc., not tracked in git)
if [[ ! -f "$HOME/.gitconfig.local" ]]; then
    if [[ -f "$SCRIPT_DIR/.gitconfig.local.example" ]]; then
        log_info "Creating ~/.gitconfig.local from example template..."
        cp "$SCRIPT_DIR/.gitconfig.local.example" "$HOME/.gitconfig.local"
        log_warning "Edit ~/.gitconfig.local to enable commit signing on this machine"
    fi
fi

# Config directories
create_symlink "$SCRIPT_DIR/.config/starship.toml" "$HOME/.config/starship.toml" "starship config"
# Ghostty: macos/ghostty or linux/ghostty - handled by main install.sh
create_symlink "$SCRIPT_DIR/.config/lazygit" "$HOME/.config/lazygit" "lazygit config"
create_symlink "$SCRIPT_DIR/.config/bat" "$HOME/.config/bat" "bat config"
create_symlink "$SCRIPT_DIR/.config/procs" "$HOME/.config/procs" "procs config"
create_symlink "$SCRIPT_DIR/.config/zellij" "$HOME/.config/zellij" "zellij config"
[[ -d "$SCRIPT_DIR/.config/herdr" ]] && create_symlink "$SCRIPT_DIR/.config/herdr" "$HOME/.config/herdr" "herdr config"

# WezTerm: lives at $SCRIPT_DIR/wezterm/ (not under .config/) so the Windows-side
# symlink under "Windows Terminal" block can target it via UNC consistently.
create_symlink "$SCRIPT_DIR/wezterm" "$HOME/.config/wezterm" "wezterm config"

# Codex CLI config
create_symlink "$SCRIPT_DIR/.codex" "$HOME/.codex" "codex config"

# Claude Code config — CLAUDE.md, skills dir, hooks, MCP wrapper scripts
mkdir -p "$HOME/.claude"
create_symlink "$SCRIPT_DIR/.claude/CLAUDE.md" "$HOME/.claude/CLAUDE.md" "claude CLAUDE.md"
create_symlink "$SCRIPT_DIR/.claude/skills" "$HOME/.claude/skills" "claude skills dir"

if [[ -d "$SCRIPT_DIR/.claude/hooks" ]]; then
    mkdir -p "$HOME/.claude/hooks"
    for hook in "$SCRIPT_DIR/.claude/hooks/"*.sh; do
        [[ -f "$hook" ]] || continue
        chmod +x "$hook"
        create_symlink "$hook" "$HOME/.claude/hooks/$(basename "$hook")" "claude hook: $(basename "$hook")"
    done
fi

if [[ -d "$SCRIPT_DIR/.claude/scripts" ]]; then
    mkdir -p "$HOME/.claude/scripts"
    for script in "$SCRIPT_DIR/.claude/scripts/"*.sh; do
        [[ -f "$script" ]] || continue
        chmod +x "$script"
        create_symlink "$script" "$HOME/.claude/scripts/$(basename "$script")" "claude script: $(basename "$script")"
    done
fi

# Cursor config — rules, agents, hook scripts, built-in skill cache
mkdir -p "$HOME/.cursor/rules" "$HOME/.cursor/agents" "$HOME/.cursor/hooks"

if [[ -d "$SCRIPT_DIR/.cursor/rules" ]]; then
    for rule in "$SCRIPT_DIR/.cursor/rules/"*.mdc; do
        [[ -f "$rule" ]] || continue
        create_symlink "$rule" "$HOME/.cursor/rules/$(basename "$rule")" "cursor rule: $(basename "$rule")"
    done
fi

if [[ -d "$SCRIPT_DIR/.cursor/agents" ]]; then
    for agent in "$SCRIPT_DIR/.cursor/agents/"*.md; do
        [[ -f "$agent" ]] || continue
        create_symlink "$agent" "$HOME/.cursor/agents/$(basename "$agent")" "cursor agent: $(basename "$agent")"
    done
fi

if [[ -d "$SCRIPT_DIR/.cursor/hooks" ]]; then
    for hook in "$SCRIPT_DIR/.cursor/hooks/"*.sh; do
        [[ -f "$hook" ]] || continue
        chmod +x "$hook"
        create_symlink "$hook" "$HOME/.cursor/hooks/$(basename "$hook")" "cursor hook: $(basename "$hook")"
    done
fi

if [[ -d "$SCRIPT_DIR/.cursor/skills-cursor" ]]; then
    create_symlink "$SCRIPT_DIR/.cursor/skills-cursor" "$HOME/.cursor/skills-cursor" "cursor skills dir"
fi

# Shared agent skills (.agents/skills — portable Agent Skills)
if [[ -d "$SCRIPT_DIR/.agents/skills" ]]; then
    mkdir -p "$HOME/.agents"
    create_symlink "$SCRIPT_DIR/.agents/skills" "$HOME/.agents/skills" "shared agent skills"
    create_symlink "$SCRIPT_DIR/.agents/skills" "$HOME/.cursor/skills" "cursor shared agent skills"
fi

# RTK hooks are dotfiles-managed config entries using native `rtk hook ...`
# processors. Do not call `rtk init` here: upstream installers may mutate
# ~/.cursor/hooks.json or Claude settings directly. Agent-specific installers
# patch those files idempotently.

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

# Windows Terminal (if on Windows/WSL)
if [[ "$IS_WSL" == "true" ]] || [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]]; then
    # Try multiple possible Windows Terminal paths
    WINDOWS_TERMINAL_PATHS=(
        "$APPDATA/Packages/Microsoft.WindowsTerminal_8wekyb3d8bbwe/LocalState"
        "/mnt/c/Users/$USER/AppData/Local/Packages/Microsoft.WindowsTerminal_8wekyb3d8bbwe/LocalState"
        "/mnt/c/Users/$USERNAME/AppData/Local/Packages/Microsoft.WindowsTerminal_8wekyb3d8bbwe/LocalState"
    )

    WINDOWS_TERMINAL_FOUND=false
    for WINDOWS_TERMINAL_DIR in "${WINDOWS_TERMINAL_PATHS[@]}"; do
        if [[ -d "$WINDOWS_TERMINAL_DIR" ]]; then
            log_info "Found Windows Terminal directory: $WINDOWS_TERMINAL_DIR"

            # Create backup of existing settings if they exist
            if [[ -f "$WINDOWS_TERMINAL_DIR/settings.json" ]]; then
                BACKUP_FILE="$WINDOWS_TERMINAL_DIR/settings.json.backup.$(date +%Y%m%d_%H%M%S)"
                log_info "Creating backup of existing Windows Terminal settings: $BACKUP_FILE"
                cp "$WINDOWS_TERMINAL_DIR/settings.json" "$BACKUP_FILE"
            fi

            create_symlink "$SCRIPT_DIR/wsl/windows-terminal/settings.json" "$WINDOWS_TERMINAL_DIR/settings.json" "Windows Terminal config"
            WINDOWS_TERMINAL_FOUND=true
            break
        fi
    done

    if [[ "$WINDOWS_TERMINAL_FOUND" == "false" ]]; then
        log_warning "Windows Terminal directory not found, skipping Windows Terminal config"
        log_info "Searched in: ${WINDOWS_TERMINAL_PATHS[*]}"
    fi

    # WezTerm: Windows dir symlink → WSL dotfiles via \\wsl$\Debian UNC path.
    # Uses PowerShell New-Item SymbolicLink (requires Developer Mode — already enabled).
    # Distro hardcoded to Debian (single-machine, won't change).
    WIN_USER="${USERNAME:-christian}"
    WEZTERM_WIN="C:\\Users\\${WIN_USER}\\.config\\wezterm"
    WEZTERM_UNC="\\\\wsl\$\\Debian\\home\\christian\\.config\\dotfiles\\wezterm"
    if powershell.exe -NoProfile -NonInteractive -Command "
        \$t = '${WEZTERM_WIN}'
        \$u = '${WEZTERM_UNC}'
        if (Test-Path \$t) {
            \$item = Get-Item \$t -ErrorAction SilentlyContinue
            if (\$item.LinkType -eq 'SymbolicLink' -and \$item.Target -like '*dotfiles*wezterm*') {
                Write-Output 'ok: wezterm symlink already correct'
                exit 0
            }
            Write-Output 'removing existing wezterm dir/link'
            Remove-Item \$t -Recurse -Force
        }
        New-Item -ItemType SymbolicLink -Path \$t -Target \$u | Out-Null
        Write-Output 'created: wezterm symlink'
    " 2>/dev/null; then
        log_success "WezTerm: Windows → WSL dotfiles symlink active"
    else
        log_warning "WezTerm: failed to create Windows symlink (check Developer Mode)"
    fi
fi

# Zed editor config (delegated to dedicated script for platform handling)
if [[ -x "$SCRIPT_DIR/scripts/zed/install-zed-config.sh" ]]; then
    bash "$SCRIPT_DIR/scripts/zed/install-zed-config.sh"
fi

# Git hooks for the dotfiles repo itself (pre-commit, pre-push live in hooks/)
if [[ -d "$SCRIPT_DIR/.git/hooks" && -d "$SCRIPT_DIR/hooks" ]]; then
    for hook in "$SCRIPT_DIR/hooks/"*; do
        [[ -f "$hook" ]] || continue
        name="$(basename "$hook")"
        ln -sfn "../../hooks/$name" "$SCRIPT_DIR/.git/hooks/$name"
        chmod +x "$hook" 2>/dev/null || true
    done
    log_success "Linked dotfiles git hooks (pre-commit, pre-push)"
fi

# Add more config directories as needed
# create_symlink "$SCRIPT_DIR/.config/nvim" "$HOME/.config/nvim" "nvim config"
# create_symlink "$SCRIPT_DIR/.config/alacritty" "$HOME/.config/alacritty" "alacritty config"

# dotfetch command
mkdir -p "$HOME/.local/bin"
create_symlink "$SCRIPT_DIR/scripts/dotfetch.sh" "$HOME/.local/bin/dotfetch" "dotfetch command"

# ob — Obsidian REST API CLI
create_symlink "$SCRIPT_DIR/scripts/ob" "$HOME/.local/bin/ob" "ob (Obsidian CLI)"

# pi — PI coding agent shim (stable across fnm project-node switches)
create_symlink "$SCRIPT_DIR/scripts/pi" "$HOME/.local/bin/pi" "pi (coding agent shim)"

# brain / kb — knowledgebase CLI shims
create_symlink "$SCRIPT_DIR/scripts/brain" "$HOME/.local/bin/brain" "brain (kb shim)"
create_symlink "$SCRIPT_DIR/scripts/kb" "$HOME/.local/bin/kb" "kb (knowledgebase CLI)"

# PI agent config — extensions, hooks, intercom
if [[ -d "$SCRIPT_DIR/.config/pi/agent/extensions" ]]; then
    mkdir -p "$HOME/.pi/agent/extensions"
    for ext in "$SCRIPT_DIR/.config/pi/agent/extensions/"*.ts; do
        [[ -f "$ext" ]] || continue
        create_symlink "$ext" "$HOME/.pi/agent/extensions/$(basename "$ext")" "pi extension: $(basename "$ext")"
    done
fi

if [[ -f "$SCRIPT_DIR/.config/pi/agent/rtk-config.json" ]]; then
    create_symlink "$SCRIPT_DIR/.config/pi/agent/rtk-config.json" "$HOME/.pi/agent/rtk-config.json" "pi rtk config"
fi

if [[ -f "$SCRIPT_DIR/.config/pi/agent/intercom/config.json" ]]; then
    mkdir -p "$HOME/.pi/agent/intercom"
    create_symlink "$SCRIPT_DIR/.config/pi/agent/intercom/config.json" "$HOME/.pi/agent/intercom/config.json" "pi intercom config"
fi

# pi custom skills tracked in dotfiles
if [[ -d "$SCRIPT_DIR/.config/pi/agent/skills" ]]; then
  mkdir -p "$HOME/.pi/agent/skills"
  for skill_dir in "$SCRIPT_DIR/.config/pi/agent/skills/"*/; do
    [[ -d "$skill_dir" ]] || continue
    skill_name="$(basename "$skill_dir")"
    create_symlink "$skill_dir" "$HOME/.pi/agent/skills/$skill_name" "pi skill: $skill_name"
  done
fi

log_success "All symlinks installed successfully!"
log_info "You may need to restart your shell or run: source ~/.zshrc"

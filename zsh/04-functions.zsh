# =============================================================================
# FUNCTIONS
# =============================================================================
# Utility functions and custom commands

# =============================================================================
# ZELLIJ WRAPPER (zj <layout>)
# =============================================================================
# zj           — attach to host-named session with default layout
# zj dev       — attach (or create) host-named session with the 'dev' layout
# zj ls        — list sessions
# zj kill      — kill the host session
zj() {
    command -v zellij >/dev/null 2>&1 || { echo "zellij not installed"; return 1; }
    local session layout
    session="$(hostname -s 2>/dev/null || echo main)"
    case "$session" in
        AKQABro|mac|Macbook*|*macbook*) layout="dev" ;;
        linuxbro|cloudbro)              layout="ops" ;;
        superbro)                       layout="vps" ;;
        monsterbro|*WSL*|*wsl*)         layout="dev" ;;
        *)                              layout="default" ;;
    esac
    layout="${ZJ_DEFAULT_LAYOUT:-$layout}"
    case "${1:-}" in
        ls|list)  zellij list-sessions ;;
        kill)     zellij kill-session "$session" ;;
        "")       zellij --layout "$layout" attach -c "$session" ;;
        *)        zellij --layout "$1" attach -c "${session}-$1" ;;
    esac
}

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
# DOTFILES UPDATE FUNCTIONS
# =============================================================================
# Companion functions for the auto-update notification system (06-autoupdate.zsh).

# Pull dotfiles and re-exec shell. Only place exec zsh is invoked.
dotfiles-update() {
    local repo="${DOTFILES_DIR:-$HOME/dotfiles}"
    local git_bin="${DOTFILES_GIT_BIN:-$(command -v /opt/homebrew/bin/git 2>/dev/null || command -v git)}"
    ( cd "$repo" && "$git_bin" pull --ff-only ) || { echo "dotfiles pull failed"; return 1; }
    if ! zsh -n "$repo/.zshrc" 2>/dev/null; then
        echo "warning: new .zshrc has syntax errors — NOT re-execing"
        return 1
    fi
    rm -f "$HOME/.cache/dotfiles/status" "$HOME/.cache/dotfiles/notified-sha"
    exec zsh
}

dotfiles-status() {
    local repo="${DOTFILES_DIR:-$HOME/dotfiles}"
    local git_bin="${DOTFILES_GIT_BIN:-$(command -v /opt/homebrew/bin/git 2>/dev/null || command -v git)}"
    ( cd "$repo" && "$git_bin" fetch && "$git_bin" status -sb )
}

# Force fresh check on next shell start
dotfiles-check() {
    rm -f "$HOME/.cache/dotfiles/last-attempt" \
          "$HOME/.cache/dotfiles/last-fetch" \
          "$HOME/.cache/dotfiles/status" \
          "$HOME/.cache/dotfiles/notified-sha"
    echo "dotfiles cache cleared — next shell will re-check"
}

dotfiles-debug() {
    local d="$HOME/.cache/dotfiles"
    echo "=== dotfiles auto-update state ==="
    echo "repo:              ${DOTFILES_DIR:-$HOME/dotfiles}"
    echo "git binary:        ${DOTFILES_GIT_BIN:-<unset>}"
    echo "timeout binary:    ${DOTFILES_TIMEOUT_BIN:-<none, using fallback>}"
    echo "throttle seconds:  ${DOTFILES_THROTTLE_SECONDS:-14400}"
    echo "autocheck:         ${DOTFILES_AUTOCHECK:-1}"
    echo "update-on-exit:    ${DOTFILES_UPDATE_ON_EXIT:-0}"
    echo
    local f age
    for f in last-attempt last-fetch status notified-sha own-pushes; do
        if [[ -f "$d/$f" ]]; then
            age=$(( $(date +%s) - $(stat -f %m "$d/$f" 2>/dev/null || stat -c %Y "$d/$f" 2>/dev/null || echo 0) ))
            echo "$f: $((age/60))m ago"
            [[ "$f" == "status" || "$f" == "notified-sha" ]] && sed 's/^/  /' "$d/$f"
        else
            echo "$f: <missing>"
        fi
    done
    if [[ ! -L "$DOTFILES_REPO/.git/hooks/pre-push" && ! -f "$DOTFILES_REPO/.git/hooks/pre-push" ]]; then
        echo
        echo "note: pre-push hook not installed — own-push suppression disabled"
        echo "      run install.sh or symlink hooks/pre-push manually"
    fi
}

# =============================================================================
# PORT UTILITIES
# =============================================================================
# Load utility functions for managing ports (uses DOTFILES_DIR from .zshrc)
if [[ -n "$DOTFILES_DIR" && -f "$DOTFILES_DIR/functions/port-utils.sh" ]]; then
    source "$DOTFILES_DIR/functions/port-utils.sh"
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

# =============================================================================
# SMART PACKAGE MANAGER DETECTION
# =============================================================================
# Auto-detects the correct package manager by walking up from cwd to find a
# lockfile. Caches result per directory to avoid repeated filesystem lookups.

typeset -gA _pm_cache

_detect_pm() {
    local dir="$PWD"

    if [[ -n "${_pm_cache[$dir]}" ]]; then
        echo "${_pm_cache[$dir]}"
        return
    fi

    local check="$dir"
    while [[ "$check" != "/" ]]; do
        [[ -f "$check/bun.lock" || -f "$check/bun.lockb" ]] && { _pm_cache[$dir]="bun"; echo "bun"; return; }
        [[ -f "$check/pnpm-lock.yaml" ]]                     && { _pm_cache[$dir]="pnpm"; echo "pnpm"; return; }
        [[ -f "$check/yarn.lock" ]]                           && { _pm_cache[$dir]="yarn"; echo "yarn"; return; }
        [[ -f "$check/package-lock.json" ]]                   && { _pm_cache[$dir]="npm"; echo "npm"; return; }
        check="$(dirname "$check")"
    done

    _pm_cache[$dir]="bun"
    echo "bun"
}

ni()   { local pm=$(_detect_pm); "$pm" install "$@"; }
na()   { local pm=$(_detect_pm); case $pm in npm) npm install "$@";; yarn) yarn add "$@";; *) "$pm" add "$@";; esac; }
nr()   { local pm=$(_detect_pm); "$pm" run "$@"; }
ns()   { local pm=$(_detect_pm); case $pm in yarn) yarn start "$@";; *) "$pm" run start "$@";; esac; }
nb()   { local pm=$(_detect_pm); "$pm" run build "$@"; }
nd()   { local pm=$(_detect_pm); "$pm" run dev "$@"; }
nt()   { local pm=$(_detect_pm); "$pm" run test "$@"; }
nup()  { local pm=$(_detect_pm); case $pm in yarn) yarn upgrade "$@";; *) "$pm" update "$@";; esac; }
nout() { local pm=$(_detect_pm); case $pm in bun) bun outdated "$@";; *) "$pm" outdated "$@";; esac; }
nls()  { local pm=$(_detect_pm); case $pm in bun) bun pm ls "$@";; *) "$pm" list "$@";; esac; }
nx()   { local pm=$(_detect_pm); case $pm in npm) npx "$@";; bun) bunx "$@";; pnpm) pnpm dlx "$@";; yarn) yarn dlx "$@";; esac; }
nrm()  { local pm=$(_detect_pm); case $pm in npm) npm uninstall "$@";; yarn) yarn remove "$@";; *) "$pm" remove "$@";; esac; }

pm() {
    case "${1:-}" in
        which)
            local pm=$(_detect_pm)
            echo "$pm (detected from lockfile)"
            local check="$PWD"
            while [[ "$check" != "/" ]]; do
                for f in bun.lock bun.lockb pnpm-lock.yaml yarn.lock package-lock.json; do
                    [[ -f "$check/$f" ]] && { echo "  lockfile: $check/$f"; return; }
                done
                check="$(dirname "$check")"
            done
            echo "  lockfile: none (using default: bun)"
            ;;
        flush)
            _pm_cache=()
            echo "pm cache cleared"
            ;;
        *)
            echo "Usage: pm <command>"
            echo "  which  - show detected package manager and lockfile"
            echo "  flush  - clear detection cache"
            echo ""
            echo "Smart aliases (auto-detect pm):"
            echo "  ni     install        na    add package"
            echo "  nr     run script     ns    start"
            echo "  nb     build          nd    dev"
            echo "  nt     test           nx    execute (npx/bunx)"
            echo "  nup    update         nout  outdated"
            echo "  nls    list           nrm   remove package"
            ;;
    esac
}

# =============================================================================
# GIT WORKTREE HELPERS
# =============================================================================
# Create new worktree with branch
gwtnew() {
    if [[ -z "$1" ]]; then
        echo "Usage: gwtnew <branch-name>"
        echo "Creates a new worktree in parallel directory with new branch"
        return 1
    fi
    
    local branch_name="$1"
    local current_dir=$(basename $(pwd))
    local worktree_path="../${current_dir}-${branch_name}"
    
    echo "Creating worktree: $worktree_path"
    git worktree add "$worktree_path" -b "$branch_name"
    
    if [[ $? -eq 0 ]]; then
        echo "✅ Worktree created successfully"
        echo "📁 Location: $worktree_path"
        echo "🌿 Branch: $branch_name"
        echo ""
        echo "To switch: cd $worktree_path"
    fi
}

# Navigate to worktree with FZF
gwtgo() {
    if ! command -v fzf &>/dev/null; then
        echo "Error: fzf is required for this function"
        return 1
    fi
    
    local worktrees=$(git worktree list 2>/dev/null)
    if [[ -z "$worktrees" ]]; then
        echo "No git worktrees found"
        return 1
    fi
    
    local selection=$(echo "$worktrees" | fzf --height 40% --reverse --border \
        --preview 'echo {} | awk "{print \$1}" | xargs ls -la' \
        --preview-window=right:50%)
    
    if [[ -n "$selection" ]]; then
        local worktree_path=$(echo "$selection" | awk '{print $1}')
        echo "Switching to: $worktree_path"
        cd "$worktree_path"
    fi
}

# code / vs — open VSCodium with file or directory
# WSL: invokes Windows codium.exe, converts Linux paths via wslpath -w
# Linux/Mac: uses native `codium`; mac falls back to `open -a VSCodium`
code() {
    if is_wsl && command -v codium.exe >/dev/null 2>&1; then
        local -a converted=()
        local arg
        for arg in "$@"; do
            if [[ -e "$arg" ]]; then
                converted+=("$(wslpath -w -- "$arg")")
            else
                converted+=("$arg")
            fi
        done
        codium.exe "${converted[@]}"
    elif command -v codium >/dev/null 2>&1; then
        codium "$@"
    elif is_macos && [[ -d /Applications/VSCodium.app ]]; then
        open -a VSCodium "$@"
    else
        echo "code: VSCodium not found on PATH" >&2
        return 127
    fi
}
alias vs='code'

# =============================================================================
# CLIPIMG (WSL-only) — save Windows clipboard image to /tmp, print path
# =============================================================================
# Usage:
#   clipimg              → /tmp/clip-<ts>.png, prints WSL path
#   clipimg foo.png      → saves to foo.png
# Path also copied to Linux clipboard via xclip if available.
clipimg() {
    is_wsl || { echo "clipimg: WSL only" >&2; return 1; }
    local out="${1:-/tmp/clip-$(date +%s).png}"
    local win_out
    win_out="$(wslpath -w "$out" 2>/dev/null)" || { echo "clipimg: wslpath failed" >&2; return 1; }
    powershell.exe -NoProfile -Command "
        Add-Type -AssemblyName System.Windows.Forms
        \$img = [System.Windows.Forms.Clipboard]::GetImage()
        if (\$img -eq \$null) { Write-Error 'no image in clipboard'; exit 1 }
        \$img.Save('$win_out', [System.Drawing.Imaging.ImageFormat]::Png)
    " >&2
    [[ -s "$out" ]] || { echo "clipimg: save failed (no image in clipboard?)" >&2; return 1; }
    echo "$out"
    command -v xclip >/dev/null 2>&1 && printf '%s' "$out" | xclip -selection clipboard 2>/dev/null
}



# =============================================================================
# INTEGRATIONS
# =============================================================================
# Editor integrations and platform-specific configurations

# =============================================================================
# CURSOR/CODE EDITOR INTEGRATION (Cross-Platform)
# =============================================================================
# Intelligently sets up 'code' and 'cursor' commands based on OS
# Works on macOS, Linux, and WSL2

# Function to safely resolve Windows user path (WSL only)
_find_windows_user_home() {
    local win_home
    win_home=$(wslpath "$(cmd.exe /C "echo %USERPROFILE%" 2>/dev/null | tr -d '\r')" 2>/dev/null)
    echo "$win_home"
}

# Function to set up Cursor integration
_setup_cursor_integration() {
    local cursor_bin=""
    local cursor_found=false

    if $IS_WSL; then
        # WSL: Check for Cursor on Windows
        local win_home=$(_find_windows_user_home)
        if [[ -n "$win_home" ]]; then
            local cursor_exe="$win_home/AppData/Local/Programs/cursor/Cursor.exe"
            if [[ -x "$cursor_exe" ]]; then
                cursor_bin="$cursor_exe"
                cursor_found=true

                # Create wrapper functions for WSL
                cursor() {
                    local target="."
                    if [[ -n "$1" ]]; then
                        target="$1"
                    fi
                    "$cursor_bin" "$(wslpath -w "$target")" >/dev/null 2>&1 &
                }

                code() {
                    cursor "$@"
                }

                # Export for subshells
                export CURSOR_PATH="$cursor_bin"
            fi
        fi
    elif $IS_MACOS; then
        # macOS: Check for Cursor.app
        if [[ -d "/Applications/Cursor.app" ]]; then
            cursor_found=true

            cursor() {
                local target="."
                if [[ -n "$1" ]]; then
                    target="$1"
                fi
                open -a "Cursor" "$target"
            }

            code() {
                cursor "$@"
            }
        # Fallback: Check if cursor CLI is in PATH
        elif command -v cursor >/dev/null 2>&1; then
            cursor_found=true
            code() {
                cursor "$@"
            }
        fi
    elif $IS_LINUX; then
        # Linux: Check if cursor is in PATH (AppImage or installed via package)
        if command -v cursor >/dev/null 2>&1; then
            cursor_found=true
            code() {
                cursor "$@"
            }
        # Check common Linux installation paths
        elif [[ -x "$HOME/.local/bin/cursor" ]]; then
            cursor_found=true
            alias cursor="$HOME/.local/bin/cursor"
            code() {
                "$HOME/.local/bin/cursor" "$@"
            }
        elif [[ -x "/usr/local/bin/cursor" ]]; then
            cursor_found=true
            alias cursor="/usr/local/bin/cursor"
            code() {
                "/usr/local/bin/cursor" "$@"
            }
        fi
    fi

    # Status message (optional - comment out if you don't want startup messages)
    # if $cursor_found; then
    #     echo "✓ Cursor integration active ($OS_TYPE)"
    # fi
}

# Run the setup
_setup_cursor_integration

# Cleanup temporary functions
unset -f _find_windows_user_home
unset -f _setup_cursor_integration

# Note: Zellij auto-attach moved to 07-zellij.zsh so it runs AFTER 06-autoupdate.zsh.
# Otherwise `exec zellij` replaces the shell before autoupdate can register hooks.


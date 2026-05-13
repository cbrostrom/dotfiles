# =============================================================================
# INTEGRATIONS
# =============================================================================
# Editor integrations and platform-specific configurations

# =============================================================================
# CURSOR EDITOR INTEGRATION (Cross-Platform)
# =============================================================================
# Sets up `cursor` command per OS. `code`/`vs` belong to VSCodium and are
# defined in 04-functions.zsh — do not redefine them here.

_find_windows_user_home() {
    local win_home
    win_home=$(wslpath "$(cmd.exe /C "echo %USERPROFILE%" 2>/dev/null | tr -d '\r')" 2>/dev/null)
    echo "$win_home"
}

_setup_cursor_integration() {
    if $IS_WSL; then
        local win_home; win_home=$(_find_windows_user_home)
        if [[ -n "$win_home" ]]; then
            local cursor_exe="$win_home/AppData/Local/Programs/cursor/Cursor.exe"
            if [[ -x "$cursor_exe" ]]; then
                export CURSOR_PATH="$cursor_exe"
                cursor() {
                    local target="."
                    [[ -n "$1" ]] && target="$1"
                    "$CURSOR_PATH" "$(wslpath -w "$target")" >/dev/null 2>&1 &
                }
            fi
        fi
    elif $IS_MACOS; then
        if [[ -d /Applications/Cursor.app ]]; then
            cursor() {
                local target="."
                [[ -n "$1" ]] && target="$1"
                open -a Cursor "$target"
            }
        fi
    elif $IS_LINUX; then
        if [[ -x "$HOME/.local/bin/cursor" ]]; then
            # shellcheck disable=SC2139
            alias cursor="$HOME/.local/bin/cursor"
        elif [[ -x /usr/local/bin/cursor ]]; then
            alias cursor=/usr/local/bin/cursor
        fi
    fi
}

_setup_cursor_integration

unset -f _find_windows_user_home
unset -f _setup_cursor_integration


# =============================================================================
# DOTFETCH ON INTERACTIVE START
# =============================================================================
# Runs dotfetch on interactive terminal start (skip in non-interactive, CI, or dumb terminals)

if [[ -o interactive && "${TERM:-}" != "dumb" && -z "${CI:-}" ]]; then
  if command -v dotfetch >/dev/null 2>&1; then
    dotfetch
  elif [[ -x "${DOTFILES_DIR:-$HOME/.config/dotfiles}/scripts/dotfetch.sh" ]]; then
    bash "${DOTFILES_DIR:-$HOME/.config/dotfiles}/scripts/dotfetch.sh"
  fi
fi

# =============================================================================
# INTEGRATIONS
# =============================================================================
# Editor integrations and platform-specific configurations

# =============================================================================
# CURSOR EDITOR INTEGRATION (Cross-Platform)
# =============================================================================
# Sets up `cursor` command per OS. `code`/`vs` (Zed-primary) are
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
        if [[ -x /usr/local/bin/cursor ]]; then
            # Prefer CLI when present; inject llmtrim env if daemon is healthy
            cursor() {
                local target="."
                [[ -n "$1" ]] && target="$1"
                if command -v llmtrim >/dev/null 2>&1 && llmtrim _alive >/dev/null 2>&1; then
                    HTTPS_PROXY='http://127.0.0.1:43117' \
                    HTTP_PROXY='http://127.0.0.1:43117' \
                    NODE_USE_ENV_PROXY=1 \
                    NODE_EXTRA_CA_CERTS="${HOME}/.llmtrim/ca.pem" \
                    SSL_CERT_FILE="${HOME}/.llmtrim/ca-bundle.pem" \
                    CURL_CA_BUNDLE="${HOME}/.llmtrim/ca-bundle.pem" \
                    /usr/local/bin/cursor "$target"
                else
                    /usr/local/bin/cursor "$target"
                fi
            }
        elif [[ -d /Applications/Cursor.app ]]; then
            cursor() {
                local target="."
                [[ -n "$1" ]] && target="$1"
                if command -v llmtrim >/dev/null 2>&1 && llmtrim _alive >/dev/null 2>&1; then
                    open -a Cursor \
                        --env HTTPS_PROXY=http://127.0.0.1:43117 \
                        --env HTTP_PROXY=http://127.0.0.1:43117 \
                        --env NODE_USE_ENV_PROXY=1 \
                        --env "NODE_EXTRA_CA_CERTS=${HOME}/.llmtrim/ca.pem" \
                        --env "SSL_CERT_FILE=${HOME}/.llmtrim/ca-bundle.pem" \
                        --env "CURL_CA_BUNDLE=${HOME}/.llmtrim/ca-bundle.pem" \
                        "$target"
                else
                    open -a Cursor "$target"
                fi
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

# dotfetch removed — costs ~0.8s per terminal open. Run manually: dotfetch

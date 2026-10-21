# =============================================================================
# PLATFORM HELPERS — used across all zsh modules and bootstrap.sh
# =============================================================================
# Source this file early. Provides:
#   is_macos / is_linux / is_wsl / is_debian        — boolean OS predicates
#   has <cmd>                                        — silent command-existence check
# =============================================================================

is_macos() { [[ "$(uname -s)" == "Darwin" ]]; }
is_linux() { [[ "$(uname -s)" == "Linux" ]]; }
is_wsl() { is_linux && { [[ -n "$WSL_DISTRO_NAME" ]] || grep -qiE '(microsoft|wsl)' /proc/version 2>/dev/null; }; }
is_debian() { is_linux && [[ -f /etc/debian_version ]]; }

has() { command -v "$1" >/dev/null 2>&1; }

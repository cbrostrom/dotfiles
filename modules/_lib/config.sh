#!/usr/bin/env bash
# User-facing module configuration.
#
# Resolution order (later wins):
#   1. Module manifest default (MODULE_DEFAULT_ENABLED)
#   2. ~/.config/dotfiles/modules.conf
#         Format:  one module name per line, prefix '!' to disable.
#         Lines starting with '#' are comments.
#         Bare module names act as explicit enables (no effect on already-enabled).
#   3. Env: DOTFILES_DISABLED="mod1,mod2"  / DOTFILES_ENABLED="mod1,mod2"
#   4. CLI: --skip=mod1,mod2  / --only=mod1,mod2
#
# The CLI flags are passed in via env vars set by bootstrap.sh:
#   _DOTFILES_CLI_ONLY  (comma-separated)
#   _DOTFILES_CLI_SKIP  (comma-separated)
#
# config_module_state <module_name> <default_enabled>
#   prints one of: enabled | disabled | only-other
#   "only-other" means --only/$DOTFILES_ENABLED was specified and this module
#   isn't in it (different from "disabled" so the runner reports it as skipped
#   for "not selected" rather than "user disabled").

if [[ "${_DOTFILES_CONFIG_LOADED:-}" == "1" ]]; then
    return 0 2>/dev/null || true
fi
_DOTFILES_CONFIG_LOADED=1

CONFIG_FILE="${DOTFILES_CONFIG_FILE:-$HOME/.config/dotfiles/modules.conf}"

# Internal: read the modules.conf file (if present) and populate two arrays.
declare -ga _CONFIG_FILE_ENABLES=()
declare -ga _CONFIG_FILE_DISABLES=()
_config_loaded_file=0
_config_load_file() {
    [[ "$_config_loaded_file" == "1" ]] && return 0
    _config_loaded_file=1
    [[ -f "$CONFIG_FILE" ]] || return 0
    local line name
    while IFS= read -r line || [[ -n "$line" ]]; do
        line="${line%%#*}"
        line="${line//[$' \t\r\n']/}"
        [[ -z "$line" ]] && continue
        if [[ "$line" == "!"* ]]; then
            name="${line#!}"
            _CONFIG_FILE_DISABLES+=("$name")
        else
            _CONFIG_FILE_ENABLES+=("$line")
        fi
    done < "$CONFIG_FILE"
}

_csv_contains() {
    local needle="$1" csv="$2"
    [[ -z "$csv" ]] && return 1
    local item
    IFS=',' read -ra _items <<< "$csv"
    for item in "${_items[@]}"; do
        item="${item// /}"
        [[ "$item" == "$needle" ]] && return 0
    done
    return 1
}

_array_contains() {
    local needle="$1"; shift
    local item
    for item in "$@"; do
        [[ "$item" == "$needle" ]] && return 0
    done
    return 1
}

config_module_state() {
    local name="$1"
    local default_enabled="${2:-true}"
    _config_load_file

    # CLI --only takes precedence: only modules in the list run.
    if [[ -n "${_DOTFILES_CLI_ONLY:-}" ]]; then
        if _csv_contains "$name" "$_DOTFILES_CLI_ONLY"; then
            echo "enabled"
        else
            echo "only-other"
        fi
        return
    fi
    if [[ -n "${DOTFILES_ENABLED:-}" ]]; then
        if _csv_contains "$name" "$DOTFILES_ENABLED"; then
            echo "enabled"
        else
            echo "only-other"
        fi
        return
    fi

    # CLI --skip / env DOTFILES_DISABLED hard-disable
    if _csv_contains "$name" "${_DOTFILES_CLI_SKIP:-}"; then
        echo "disabled"; return
    fi
    if _csv_contains "$name" "${DOTFILES_DISABLED:-}"; then
        echo "disabled"; return
    fi

    # File-level overrides
    if _array_contains "$name" "${_CONFIG_FILE_DISABLES[@]:-}"; then
        echo "disabled"; return
    fi
    if _array_contains "$name" "${_CONFIG_FILE_ENABLES[@]:-}"; then
        echo "enabled"; return
    fi

    # Manifest default
    if [[ "$default_enabled" == "true" ]]; then
        echo "enabled"
    else
        echo "disabled"
    fi
}

# Print the active config file path (or empty if none).
config_file_path() {
    [[ -f "$CONFIG_FILE" ]] && echo "$CONFIG_FILE"
}

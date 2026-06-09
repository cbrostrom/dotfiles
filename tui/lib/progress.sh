#!/usr/bin/env bash
# Shared progress renderer for TUI update/install flows.
#
# Usage:
#   . "$DOTFILES_DIR/tui/lib/progress.sh"
#   render_progress "$log_file" < <(bootstrap_subprocess)
#
# Reads structured markers emitted by loader.sh (DOTFILES_STRUCTURED=1):
#   MODULE_COUNT:N      total modules that will run
#   MODULE_START:name   module about to execute
#   MODULE_DONE:name    module succeeded
#   MODULE_FAIL:name    module failed

_PROG_CURRENT=0
_PROG_TOTAL=0
_PROG_MODULE=""
declare -a _PROG_FAILED=()
declare -a _PROG_DONE=()

_prog_bar() {
    local width=14
    local filled=$(( _PROG_TOTAL > 0 ? (_PROG_CURRENT * width) / _PROG_TOTAL : 0 ))
    local empty=$(( width - filled ))
    local bar="" i
    for (( i=0; i<filled; i++ )); do bar+="█"; done
    for (( i=0; i<empty; i++ )); do bar+="░"; done
    printf '%s' "$bar"
}

_prog_line() {
    local bar
    bar="$(_prog_bar)"
    local total_str="${_PROG_TOTAL:-?}"
    printf '\r\033[K  \033[2m[%d/%s]\033[0m %s  %s' \
        "$_PROG_CURRENT" "$total_str" "$bar" "$_PROG_MODULE"
}

render_progress() {
    local log_path="$1"

    while IFS= read -r line; do
        case "$line" in
            MODULE_COUNT:*)
                _PROG_TOTAL="${line#MODULE_COUNT:}"
                _prog_line
                ;;
            MODULE_START:*)
                _PROG_MODULE="${line#MODULE_START:}"
                _prog_line
                ;;
            MODULE_DONE:*)
                _PROG_DONE+=("${line#MODULE_DONE:}")
                (( _PROG_CURRENT++ )) || true
                _prog_line
                ;;
            MODULE_FAIL:*)
                _PROG_FAILED+=("${line#MODULE_FAIL:}")
                (( _PROG_CURRENT++ )) || true
                _prog_line
                ;;
        esac
    done

    printf '\n\n'

    local ok_count="${#_PROG_DONE[@]}"
    local fail_count="${#_PROG_FAILED[@]}"

    if (( fail_count == 0 )); then
        gum style --foreground 10 --bold "  ✓ Done — $ok_count module(s) complete"
    else
        gum style --foreground 9 --bold "  ✗ $ok_count ok, $fail_count failed:"
        local f
        for f in "${_PROG_FAILED[@]}"; do
            gum style --foreground 9 "    • $f"
        done
    fi

    echo
    gum style --foreground 8 "  Log: $log_path"
}

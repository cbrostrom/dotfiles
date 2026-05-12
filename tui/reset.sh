#!/usr/bin/env bash
# Reset screen — destructive, confirmed, dry-run-first.
#
# Lists modules that declare an uninstall.sh, lets the user multi-select,
# offers a Dry-run preview, then executes via `bootstrap.sh --reset=...`.

set -euo pipefail

DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

. "$DOTFILES_DIR/modules/_lib/log.sh"
. "$DOTFILES_DIR/modules/_lib/platform.sh"
. "$DOTFILES_DIR/modules/_lib/config.sh"
. "$DOTFILES_DIR/modules/_lib/loader.sh"

# Echo names of modules that have an uninstall.sh script.
_reset_capable_modules() {
    DOTFILES_QUIET=1 modules_init >/dev/null 2>&1
    DOTFILES_QUIET=1 modules_discover >/dev/null 2>&1
    local name d
    for name in "${_MODULES_REGISTRY[@]}"; do
        d="${_MODULES_DIR[$name]}"
        [[ -f "$d/uninstall.sh" ]] && printf '%s\n' "$name"
    done
}

_reset_label() {
    local name="$1"
    printf '%-18s — %s' "$name" "${_MODULES_DESC[$name]:-}"
}

run_reset() {
    echo
    gum style --bold --foreground 9 "RESET"
    echo
    gum style --foreground 8 \
        "  Removes symlinks/state created by selected modules. Only symlinks"
    gum style --foreground 8 \
        "  pointing into \$DOTFILES_DIR are touched — third-party files are safe."
    echo

    local -a names=()
    while IFS= read -r n; do names+=("$n"); done < <(_reset_capable_modules)

    if [[ ${#names[@]} -eq 0 ]]; then
        gum style --foreground 220 "  No modules expose an uninstall.sh."
        echo
        read -rsp "Press any key to return…" -n1
        return
    fi

    local -a labels=()
    local n
    for n in "${names[@]}"; do
        labels+=("$(_reset_label "$n")")
    done

    gum style --foreground 8 "  Pick modules to reset. Space toggles, Enter confirms."
    local picked
    picked="$(printf '%s\n' "${labels[@]}" | \
        gum choose --no-limit \
            --header "modules with an uninstall.sh (nothing pre-selected)" )" || picked=""

    if [[ -z "$picked" ]]; then
        gum style --foreground 220 "  Nothing selected — aborting."
        echo
        read -rsp "Press any key to return…" -n1
        return
    fi

    local -a sel_names=()
    while IFS= read -r label; do
        [[ -z "$label" ]] && continue
        local mod="${label%% *}"
        sel_names+=("$mod")
    done <<< "$picked"

    local sel_csv
    sel_csv="$(IFS=,; echo "${sel_names[*]}")"

    # Action menu — preview / execute / cancel.
    local action
    action="$(printf 'Dry-run (preview)\nExecute reset\nCancel' | \
        gum choose --header "what next for: $sel_csv ?")" || action="Cancel"

    case "$action" in
        "Dry-run"*)
            echo
            bash "$DOTFILES_DIR/bootstrap.sh" --reset="$sel_csv" --dry-run
            echo
            read -rsp "Press any key to return…" -n1
            ;;
        "Execute"*)
            if ! gum confirm "Really reset: $sel_csv? Backups will be restored if present."; then
                gum style --foreground 220 "  Cancelled."
                read -rsp "Press any key…" -n1
                return
            fi
            echo
            if bash "$DOTFILES_DIR/bootstrap.sh" --reset="$sel_csv"; then
                gum style --foreground 10 --bold "  ✓ Reset complete"
            else
                gum style --foreground 9 --bold "  ✗ Reset finished with errors"
            fi
            echo
            read -rsp "Press any key to return…" -n1
            ;;
        *)
            ;;
    esac
}

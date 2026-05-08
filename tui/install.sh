#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
export DOTFILES_DIR

# Module-driven install picker.
. "$DOTFILES_DIR/modules/_lib/log.sh"
. "$DOTFILES_DIR/modules/_lib/platform.sh"
. "$DOTFILES_DIR/modules/_lib/config.sh"
. "$DOTFILES_DIR/modules/_lib/loader.sh"

run_install() {
    echo
    gum style --bold --foreground 220 "INSTALL / SETUP"

    local plat prof
    plat="$(platform_tag)"
    prof="$(profile_tag)"
    gum style --foreground 8 "  Platform: $plat   Profile: $prof"
    echo

    modules_init
    modules_discover

    # Build list of pickable modules: exclude platform/profile mismatches.
    local -a opts=() default_selected=() name action label
    while IFS= read -r name; do
        action="$(_decide_module_action "$name")"
        case "$action" in
            run|skip-disabled|skip-not-selected)
                # eligible (state may be off, but user can opt in here)
                label="$name — ${_MODULES_DESC[$name]}"
                opts+=("$label")
                # Pre-select modules that would run by default
                if [[ "$action" == "run" ]]; then
                    default_selected+=("$label")
                fi
                ;;
        esac
    done < <(modules_list_all)

    if [[ ${#opts[@]} -eq 0 ]]; then
        gum style --foreground 9 "No modules eligible for this platform/profile."
        return
    fi

    local sel_csv
    sel_csv="$(IFS=,; echo "${default_selected[*]}")"

    local _tmpsel
    _tmpsel="$(mktemp)"
    gum choose --no-limit \
        --header "Select modules to install (already-installed will re-run idempotently):" \
        --selected "$sel_csv" \
        "${opts[@]}" > "$_tmpsel" || true

    local -a SELECTED=()
    while IFS= read -r line; do
        [[ -n "$line" ]] && SELECTED+=("${line%% — *}")
    done < "$_tmpsel"
    rm -f "$_tmpsel"

    [[ ${#SELECTED[@]} -eq 0 ]] && { echo "Nothing selected."; return; }

    echo
    gum style --foreground 8 "Will run:"
    for s in "${SELECTED[@]}"; do gum style --foreground 8 "  • $s"; done
    echo
    gum confirm "Proceed?" || return

    # Run each module via bootstrap.sh --only=name.
    local failed=()
    for mod in "${SELECTED[@]}"; do
        if gum spin --title "Running $mod" -- bash "$DOTFILES_DIR/bootstrap.sh" "--only=$mod"; then
            gum style --foreground 10 "  ✓ $mod"
        else
            gum style --foreground 9  "  ✗ $mod"
            failed+=("$mod")
        fi
    done

    echo
    if [[ ${#failed[@]} -eq 0 ]]; then
        gum style --foreground 10 --bold "All selected modules complete."
    else
        gum style --foreground 9 --bold "Completed with failures:"
        for f in "${failed[@]}"; do gum style --foreground 9 "  • $f"; done
    fi
    echo
    read -rsp "Press any key to return…" -n1
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_install
fi

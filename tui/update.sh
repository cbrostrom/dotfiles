#!/usr/bin/env bash
# Profile- and host-aware Update screen.
#
# Discovers modules, filters to those applicable on this host (platform +
# profile + user config), lets the user multi-select which to update, then
# delegates to `bootstrap.sh --update --only=...` so the run reuses topo,
# dependency, and state-recording logic.

set -euo pipefail

DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

. "$DOTFILES_DIR/modules/_lib/log.sh"
. "$DOTFILES_DIR/modules/_lib/platform.sh"
. "$DOTFILES_DIR/modules/_lib/config.sh"
. "$DOTFILES_DIR/modules/_lib/loader.sh"

# Echo names of modules eligible to run on this host (platform + profile +
# user config + required commands present).
_update_eligible_modules() {
    DOTFILES_QUIET=1 modules_init >/dev/null 2>&1
    DOTFILES_QUIET=1 modules_discover >/dev/null 2>&1
    local name action
    for name in "${_MODULES_REGISTRY[@]}"; do
        action="$(_decide_module_action "$name")"
        [[ "$action" == "run" ]] || continue
        printf '%s\n' "$name"
    done
}

_update_label() {
    local name="$1"
    printf '%-18s — %s' "$name" "${_MODULES_DESC[$name]:-}"
}

run_update() {
    echo
    gum style --bold --foreground 220 "UPDATE"
    echo

    gum style --foreground 8 \
        "  Host: $(hostname -s 2>/dev/null || hostname)   Platform: $(platform_tag)   Profile: $(profile_tag)"
    echo

    # 1. Pull latest first — always.
    if gum spin --title "Pulling latest from git" -- \
           git -C "$DOTFILES_DIR" pull --rebase --autostash; then
        gum style --foreground 10 "  ✓ Pulled latest from git"
    else
        gum style --foreground 9 "  ✗ git pull failed (continuing with local copy)"
    fi
    echo

    # 2. Enumerate eligible modules.
    local -a names=()
    while IFS= read -r n; do names+=("$n"); done < <(_update_eligible_modules)

    if [[ ${#names[@]} -eq 0 ]]; then
        gum style --foreground 220 "  No applicable modules for this host."
        echo
        read -rsp "Press any key to return…" -n1
        return
    fi

    # 3. Multi-select labels.
    local -a labels=()
    local n
    for n in "${names[@]}"; do
        labels+=("$(_update_label "$n")")
    done

    gum style --foreground 8 "  Pick what to update. Space toggles, Enter confirms."
    local picked
    picked="$(printf '%s\n' "${labels[@]}" | \
        gum choose --no-limit \
            --header "applicable on this host (all pre-selected)" \
            --selected="$(IFS=,; echo "${labels[*]}")" )" || picked=""

    if [[ -z "$picked" ]]; then
        gum style --foreground 220 "  Nothing selected — aborting."
        echo
        read -rsp "Press any key to return…" -n1
        return
    fi

    # 4. Extract module names from selected labels.
    local -a sel_names=()
    while IFS= read -r label; do
        [[ -z "$label" ]] && continue
        local mod="${label%% *}"
        sel_names+=("$mod")
    done <<< "$picked"

    local sel_csv
    sel_csv="$(IFS=,; echo "${sel_names[*]}")"

    echo
    gum style --foreground 8 "  Updating: $sel_csv"
    echo

    # 5. Delegate to bootstrap.sh (handles topo, deps, state recording).
    local failed=0
    if bash "$DOTFILES_DIR/bootstrap.sh" --update --only="$sel_csv"; then
        gum style --foreground 10 --bold "  ✓ Update complete"
    else
        gum style --foreground 9 --bold "  ✗ Update finished with errors"
        failed=1
    fi
    echo
    read -rsp "Press any key to return…" -n1
    return $failed
}

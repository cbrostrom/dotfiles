#!/usr/bin/env bash
# Module-driven install picker.
#
# Flow:
#   1. Workflow selector (writes DOTFILES_WORKFLOWS to ~/.zshrc.local)
#   2. Module picker — all default-enabled pre-selected
#   3. Per-module gum spin with structured output captured to timestamped log
#   4. Summary + log path

set -euo pipefail

DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
export DOTFILES_DIR

. "$DOTFILES_DIR/modules/_lib/log.sh"
. "$DOTFILES_DIR/modules/_lib/platform.sh"
. "$DOTFILES_DIR/modules/_lib/config.sh"
. "$DOTFILES_DIR/modules/_lib/loader.sh"

_LOG_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/logs"

_workflow_selector() {
    local current=""
    [[ -f "$HOME/.zshrc.local" ]] && \
        current="$(grep -E '^export DOTFILES_WORKFLOWS=' "$HOME/.zshrc.local" 2>/dev/null \
            | head -1 | sed 's/.*=//;s/"//g;s/'"'"'//g')"

    gum style --foreground 8 "  Active workflows: ${current:-none}"
    echo

    local -a wf_opts=("developer" "work")
    local -a presels=()
    [[ "$current" == *"developer"* ]] && presels+=("developer")
    [[ "$current" == *"work"* ]] && presels+=("work")

    local presel_arg=""
    [[ ${#presels[@]} -gt 0 ]] && presel_arg="$(IFS=,; echo "${presels[*]}")"

    local chosen="" _wf_tmp
    _wf_tmp="$(mktemp)"
    printf '%s\n' "${wf_opts[@]}" | \
        gum choose --no-limit \
            --header "Workflows (Space=toggle, Enter=confirm):" \
            ${presel_arg:+--selected="$presel_arg"} > "$_wf_tmp" 2>/dev/null || true
    chosen="$(<"$_wf_tmp")"
    rm -f "$_wf_tmp"

    local new_wf
    new_wf="$(printf '%s' "$chosen" | tr '\n' ',' | sed 's/,$//')"

    if [[ "$new_wf" != "$current" ]]; then
        if [[ -f "$HOME/.zshrc.local" ]] && grep -q "DOTFILES_WORKFLOWS" "$HOME/.zshrc.local"; then
            sed -i "s|^export DOTFILES_WORKFLOWS=.*|export DOTFILES_WORKFLOWS=\"$new_wf\"|" "$HOME/.zshrc.local"
        else
            echo "export DOTFILES_WORKFLOWS=\"$new_wf\"" >> "$HOME/.zshrc.local"
        fi
        gum style --foreground 10 "  ✓ Workflows → ${new_wf:-none}"
    fi

    export DOTFILES_WORKFLOWS="$new_wf"
}

run_install() {
    echo
    gum style --bold --foreground 220 "INSTALL / SETUP"

    local plat prof
    plat="$(platform_tag)"
    prof="$(profile_tag)"
    gum style --foreground 8 "  Platform: $plat   Profile: $prof"
    echo

    # 1. Workflow selector
    _workflow_selector
    echo

    modules_init
    modules_discover

    # 2. Module picker
    local -a opts=() default_selected=() name action label
    while IFS= read -r name; do
        action="$(_decide_module_action "$name")"
        case "$action" in
            run|skip-disabled|skip-not-selected)
                label="$name — ${_MODULES_DESC[$name]}"
                opts+=("$label")
                [[ "$action" == "run" ]] && default_selected+=("$label")
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
        --header "Select modules to install (idempotent — safe to re-run):" \
        --selected "$sel_csv" \
        "${opts[@]}" > "$_tmpsel" || true

    local -a SELECTED=()
    while IFS= read -r line; do
        [[ -n "$line" ]] && SELECTED+=("${line%% — *}")
    done < "$_tmpsel"
    rm -f "$_tmpsel"

    [[ ${#SELECTED[@]} -eq 0 ]] && { gum style --foreground 220 "Nothing selected."; return; }

    echo
    gum style --foreground 8 "Will install:"
    for s in "${SELECTED[@]}"; do gum style --foreground 8 "  • $s"; done
    echo
    gum confirm "Proceed?" || return

    # 3. Set up log file
    mkdir -p "$_LOG_DIR"
    local log_file="$_LOG_DIR/install-$(date '+%Y%m%d-%H%M%S').log"
    {
        printf '=== dotfiles install ===\n'
        printf 'Date:      %s\n' "$(date)"
        printf 'Host:      %s\n' "$(hostname -s 2>/dev/null || hostname)"
        printf 'Profile:   %s\n' "$prof"
        printf 'Workflows: %s\n' "${DOTFILES_WORKFLOWS:-none}"
        printf '\n'
    } > "$log_file"

    # 4. Run per-module with spinner; capture all output to log
    echo
    local -a failed=()
    for mod in "${SELECTED[@]}"; do
        if DOTFILES_STRUCTURED=1 \
           DOTFILES_RUN_LOG="$log_file" \
           DOTFILES_SKIP_DOCTOR=1 \
           gum spin --title "  Installing $mod…" -- \
           bash "$DOTFILES_DIR/bootstrap.sh" "--only=$mod"; then
            gum style --foreground 10 "  ✓ $mod"
        else
            gum style --foreground 9  "  ✗ $mod"
            failed+=("$mod")
        fi
    done

    echo
    if [[ ${#failed[@]} -eq 0 ]]; then
        gum style --foreground 10 --bold "  ✓ All modules installed."
    else
        gum style --foreground 9 --bold "  ✗ Completed with failures:"
        for f in "${failed[@]}"; do gum style --foreground 9 "    • $f"; done
    fi

    echo
    gum style --foreground 8 "  Log: $log_file"
    echo
    read -rsp "Press any key to return…" -n1; echo
}

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && run_install

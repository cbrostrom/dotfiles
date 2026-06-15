#!/usr/bin/env bash
# Profile- and host-aware Update screen.
#
# Flow:
#   1. git pull
#   2. Workflow selector (writes DOTFILES_WORKFLOWS to ~/.zshrc.local)
#   3. Module picker with freshness labels (new/stale/failed pre-selected; current not)
#   4. Structured progress bar — all module output captured to timestamped log
#   5. Doctor (quiet) — issue count shown in summary; full output in log

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then set -euo pipefail; fi

DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

. "$DOTFILES_DIR/modules/_lib/log.sh"
. "$DOTFILES_DIR/modules/_lib/platform.sh"
. "$DOTFILES_DIR/modules/_lib/config.sh"
. "$DOTFILES_DIR/modules/_lib/loader.sh"
. "$DOTFILES_DIR/tui/lib/progress.sh"

_RUN_STATE_DIR_TUI="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/runs"
_LOG_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/logs"

# Returns: new | stale | failed | current
_module_freshness() {
    local name="$1"
    local state_file="$_RUN_STATE_DIR_TUI/$name"
    local fail_file="$_RUN_STATE_DIR_TUI/$name.failed"
    local module_dir="$DOTFILES_DIR/modules/$name"

    [[ -f "$fail_file" ]] && { echo "failed"; return; }
    [[ ! -f "$state_file" ]] && { echo "new"; return; }

    if [[ -d "$module_dir" ]] && \
       find "$module_dir" -name "*.sh" -newer "$state_file" 2>/dev/null | grep -q .; then
        echo "stale"
    else
        echo "current"
    fi
}

_workflow_selector() {
    local current=""
    [[ -f "$HOME/.zshrc.local" ]] && \
        current="$(grep -E '^export DOTFILES_WORKFLOWS=' "$HOME/.zshrc.local" 2>/dev/null \
            | head -1 | sed 's/.*=//;s/"//g;s/'"'"'//g')"

    gum style --foreground 8 "  Active workflows: ${current:-none}"
    echo

    # Skip interactive selection when no TTY (SSH without pty, CI, server-headless).
    if [[ -n "${DOTFILES_NONINTERACTIVE:-}" ]]; then
        export DOTFILES_WORKFLOWS="${current:-}"
        return
    fi

    # Skip picker if workflows already configured — no interaction needed.
    if [[ -n "$current" ]]; then
        export DOTFILES_WORKFLOWS="$current"
        return
    fi

    local -a wf_opts=("developer" "work")

    local chosen="" _wf_tmp
    _wf_tmp="$(mktemp)"
    printf '%s\n' "${wf_opts[@]}" | \
        gum choose --no-limit \
            --header "Workflows (Space=toggle, Enter=confirm):" \
            > "$_wf_tmp" 2>/dev/null || true
    chosen="$(<"$_wf_tmp")"
    rm -f "$_wf_tmp"

    local new_wf
    new_wf="$(printf '%s' "$chosen" | tr '\n' ',' | sed 's/,$//')"

    if [[ -f "$HOME/.zshrc.local" ]] && grep -q "DOTFILES_WORKFLOWS" "$HOME/.zshrc.local"; then
        sed -i "s|^export DOTFILES_WORKFLOWS=.*|export DOTFILES_WORKFLOWS=\"$new_wf\"|" "$HOME/.zshrc.local"
    else
        echo "export DOTFILES_WORKFLOWS=\"$new_wf\"" >> "$HOME/.zshrc.local"
    fi
    gum style --foreground 10 "  ✓ Workflows → ${new_wf:-none}"
    export DOTFILES_WORKFLOWS="$new_wf"
}

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

run_update() {
    echo
    gum style --bold --foreground 220 "UPDATE"
    echo
    gum style --foreground 8 \
        "  Host: $(hostname -s 2>/dev/null || hostname)   Platform: $(platform_tag)   Profile: $(profile_tag)"
    echo

    # 1. Pull latest
    local _pull_tmp
    _pull_tmp="$(mktemp)"
    if git -C "$DOTFILES_DIR" pull --rebase --autostash >"$_pull_tmp" 2>&1; then
        gum style --foreground 10 "  ✓ Pulled latest from git"
    else
        local _pull_msg
        _pull_msg="$(head -3 "$_pull_tmp" | tr '\n' ' ')"
        gum style --foreground 9 "  ✗ git pull failed — ${_pull_msg:-unknown error}"
        local _unmerged
        _unmerged="$(git -C "$DOTFILES_DIR" diff --name-only --diff-filter=U 2>/dev/null)"
        if [[ -n "$_unmerged" ]]; then
            gum style --foreground 9 "  Conflicted files (resolve before re-running update):"
            while IFS= read -r _f; do
                gum style --foreground 9 "    $_f"
            done <<< "$_unmerged"
            gum style --foreground 8 "  Fix: git add <file> && git commit  —or—  git checkout -- <file> to discard local"
        else
            gum style --foreground 8 "  Hints: SSH agent forwarding? Try: ssh -A  |  git pull manually  |  check remote: git remote -v"
        fi
    fi
    rm -f "$_pull_tmp"
    echo

    # 2. Workflow selector
    _workflow_selector
    echo

    # 3. Enumerate modules with freshness state
    local -a names=()
    while IFS= read -r n; do names+=("$n"); done < <(_update_eligible_modules)

    if [[ ${#names[@]} -eq 0 ]]; then
        gum style --foreground 220 "  No applicable modules for this host."
        echo; [[ -z "${DOTFILES_NONINTERACTIVE:-}" ]] && { read -rsp "Press any key to return…" -n1; echo; }; return
    fi

    local -a labels=() presels=()
    local n fresh label
    for n in "${names[@]}"; do
        fresh="$(_module_freshness "$n")"
        label="$(printf '%-20s (%s)' "$n" "$fresh")"
        labels+=("$label")
        [[ "$fresh" != "current" ]] && presels+=("$label")
    done

    local presel_csv=""
    [[ ${#presels[@]} -gt 0 ]] && presel_csv="$(IFS=,; echo "${presels[*]}")"

    # Non-interactive + all current — nothing to do, skip picker entirely.
    if [[ ${#presels[@]} -eq 0 ]] && [[ -n "${DOTFILES_NONINTERACTIVE:-}" ]]; then
        gum style --foreground 10 "  All modules up to date."
        echo; return
    fi

    gum style --foreground 8 "  (new/stale/failed) = pre-selected    (current) = skip"
    echo

    local picked="" _pick_tmp
    _pick_tmp="$(mktemp)"
    if [[ -z "${DOTFILES_NONINTERACTIVE:-}" ]]; then
        local -a _gum_pick_args=(--no-limit --header "Space=toggle  Enter=confirm")
        [[ -n "$presel_csv" ]] && _gum_pick_args+=(--selected="$presel_csv")
        printf '%s\n' "${labels[@]}" | \
            gum choose "${_gum_pick_args[@]}" > "$_pick_tmp" 2>/dev/null || true
    else
        # No TTY — auto-run pre-selected (new/stale/failed) modules unattended.
        printf '%s\n' "${presels[@]}" > "$_pick_tmp"
    fi
    picked="$(<"$_pick_tmp")"
    rm -f "$_pick_tmp"

    if [[ -z "$picked" ]]; then
        gum style --foreground 10 "  All modules up to date."
        echo; return
    fi

    # Extract bare module names (before the first space)
    local -a sel_names=()
    while IFS= read -r lbl; do
        [[ -z "$lbl" ]] && continue
        sel_names+=("${lbl%%[[:space:]]*}")
    done <<< "$picked"

    local sel_csv
    sel_csv="$(IFS=,; echo "${sel_names[*]}")"

    echo
    gum style --foreground 8 "  Running: $sel_csv"
    echo

    # 4. Set up log file
    mkdir -p "$_LOG_DIR"
    local log_file="$_LOG_DIR/run-$(date '+%Y%m%d-%H%M%S').log"
    {
        printf '=== dotfiles update ===\n'
        printf 'Date:      %s\n' "$(date)"
        printf 'Host:      %s\n' "$(hostname -s 2>/dev/null || hostname)"
        printf 'Profile:   %s\n' "$(profile_tag)"
        printf 'Workflows: %s\n' "${DOTFILES_WORKFLOWS:-none}"
        printf 'Modules:   %s\n' "$sel_csv"
        printf '\n'
    } > "$log_file"

    # 5. Run with structured output — TUI renders live progress bar
    render_progress "$log_file" < <(
        DOTFILES_STRUCTURED=1 \
        DOTFILES_RUN_LOG="$log_file" \
        DOTFILES_SKIP_DOCTOR=1 \
        bash "$DOTFILES_DIR/bootstrap.sh" --only="$sel_csv" 2>>"$log_file"
    )

    # 6. Doctor: full output to log, issue count to screen
    local doctor_issues=0
    bash "$DOTFILES_DIR/scripts/doctor.sh" --quiet >> "$log_file" 2>&1 || doctor_issues=$?
    if (( doctor_issues > 0 )); then
        gum style --foreground 220 "  ⚠  Doctor: $doctor_issues issue(s) — see log"
    else
        gum style --foreground 10 "  ✓  Doctor: clean"
    fi

    # 7. Cleanup orphaned agent worktrees
    bash "$DOTFILES_DIR/scripts/cleanup-agent-worktrees.sh" >> "$log_file" 2>&1 || true

    echo
    [[ -z "${DOTFILES_NONINTERACTIVE:-}" ]] && { read -rsp "Press any key to return…" -n1; echo; }
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then run_update; fi

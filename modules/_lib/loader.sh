#!/usr/bin/env bash
# Module discovery, validation, dependency resolution, and execution.
#
# Module layout:
#   modules/<name>/
#     module.sh       (required) — manifest, sourced for variables
#     install.sh      (required) — implementation, executed via bash
#     status.sh       (optional) — exits 0 if installed/healthy, 1 if needs install
#     update.sh       (optional) — re-run friendly variant; defaults to install.sh
#     uninstall.sh    (optional) — cleanup
#
# Manifest variables (declared in module.sh — all optional except NAME):
#   MODULE_NAME              must match directory name
#   MODULE_DESC              one-line description
#   MODULE_PLATFORMS         space-separated: macos linux wsl all  (default: all)
#   MODULE_PROFILES          space-separated: desktop-full server-headless wsl all  (default: all)
#   MODULE_CORE              true|false — core modules cannot be disabled (default: false)
#   MODULE_DEPENDS           space-separated module names that must run first
#   MODULE_REQUIRES          space-separated commands that must exist on PATH
#   MODULE_DEFAULT_ENABLED   true|false — default state if user hasn't decided (default: true)
#
# Public API:
#   modules_init [<modules_dir>]
#   modules_discover                     # populates the registry
#   modules_list_all                     # echo all module names (registry order)
#   modules_run_all                      # run everything that is enabled and matches platform/profile
#   modules_run <name> [<name>...]       # run specific modules (still resolves deps)
#   modules_status <name>                # echo: missing | clean | dirty | unknown
#   modules_print_table                  # human-readable status table

if [[ "${_DOTFILES_LOADER_LOADED:-}" == "1" ]]; then
    return 0 2>/dev/null || true
fi
_DOTFILES_LOADER_LOADED=1

_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
. "$_LIB_DIR/log.sh"
# shellcheck source=/dev/null
. "$_LIB_DIR/platform.sh"
# shellcheck source=/dev/null
. "$_LIB_DIR/config.sh"

declare -ga _MODULES_REGISTRY=()                   # ordered list of discovered names
declare -gA _MODULES_DIR=()                        # name -> module dir
declare -gA _MODULES_DESC=()
declare -gA _MODULES_PLATFORMS=()
declare -gA _MODULES_PROFILES=()
declare -gA _MODULES_CORE=()
declare -gA _MODULES_DEPENDS=()
declare -gA _MODULES_REQUIRES=()
declare -gA _MODULES_DEFAULT_ENABLED=()
MODULES_DIR=""

modules_init() {
    MODULES_DIR="${1:-${MODULES_DIR:-$DOTFILES_DIR/modules}}"
    if [[ ! -d "$MODULES_DIR" ]]; then
        err "modules dir not found: $MODULES_DIR"
        return 1
    fi
}

# Source a manifest in a clean subshell-like way so vars don't leak across modules.
# We unset known module vars before sourcing and capture them after.
_source_manifest() {
    local manifest="$1"
    unset MODULE_NAME MODULE_DESC MODULE_PLATFORMS MODULE_PROFILES \
          MODULE_CORE MODULE_DEPENDS MODULE_REQUIRES MODULE_DEFAULT_ENABLED
    # shellcheck source=/dev/null
    . "$manifest"
}

modules_discover() {
    [[ -n "$MODULES_DIR" ]] || modules_init
    _MODULES_REGISTRY=()
    local d name manifest
    for d in "$MODULES_DIR"/*/; do
        [[ -d "$d" ]] || continue
        name="$(basename "$d")"
        # underscore-prefixed dirs are libs, not modules
        [[ "$name" == _* ]] && continue
        manifest="$d/module.sh"
        if [[ ! -f "$manifest" ]]; then
            warn "module '$name' missing module.sh — skipping"
            continue
        fi
        if ! _source_manifest "$manifest" 2>/dev/null; then
            warn "module '$name' has invalid module.sh — skipping"
            continue
        fi
        if [[ -z "${MODULE_NAME:-}" ]]; then
            warn "module '$name' missing MODULE_NAME — skipping"
            continue
        fi
        if [[ "$MODULE_NAME" != "$name" ]]; then
            warn "module dir '$name' declares MODULE_NAME='$MODULE_NAME' (should match) — using '$name'"
        fi
        _MODULES_REGISTRY+=("$name")
        _MODULES_DIR[$name]="$d"
        _MODULES_DESC[$name]="${MODULE_DESC:-}"
        _MODULES_PLATFORMS[$name]="${MODULE_PLATFORMS:-all}"
        _MODULES_PROFILES[$name]="${MODULE_PROFILES:-all}"
        _MODULES_CORE[$name]="${MODULE_CORE:-false}"
        _MODULES_DEPENDS[$name]="${MODULE_DEPENDS:-}"
        _MODULES_REQUIRES[$name]="${MODULE_REQUIRES:-}"
        _MODULES_DEFAULT_ENABLED[$name]="${MODULE_DEFAULT_ENABLED:-true}"
    done
}

modules_list_all() {
    printf "%s\n" "${_MODULES_REGISTRY[@]}"
}

# modules_status <name> — echoes one of: missing | clean | dirty | unknown
modules_status() {
    local name="$1"
    local d="${_MODULES_DIR[$name]:-}"
    [[ -z "$d" ]] && { echo "missing"; return; }
    if [[ -x "$d/status.sh" ]]; then
        if bash "$d/status.sh" >/dev/null 2>&1; then
            echo "clean"
        else
            echo "dirty"
        fi
    else
        echo "unknown"
    fi
}

# Resolve a list of module names into a topo-ordered list, including transitive deps.
# Echoes ordered names one per line. Cycles abort with err.
_modules_topo_order() {
    local -a roots=("$@")
    local -A seen=() done=()
    local -a ordered=()

    _visit() {
        local n="$1"
        if [[ "${seen[$n]:-}" == "visiting" ]]; then
            err "module dependency cycle detected at '$n'"
            return 2
        fi
        [[ "${done[$n]:-}" == "1" ]] && return 0
        if [[ -z "${_MODULES_DIR[$n]:-}" ]]; then
            err "unknown module: $n"
            return 2
        fi
        seen[$n]="visiting"
        local dep
        for dep in ${_MODULES_DEPENDS[$n]:-}; do
            _visit "$dep" || return $?
        done
        seen[$n]="visited"
        done[$n]=1
        ordered+=("$n")
    }

    local r
    for r in "${roots[@]}"; do
        _visit "$r" || return $?
    done
    printf "%s\n" "${ordered[@]}"
}

# decide_module_action <name>
# Echoes one of:
#   run                — eligible, run it
#   skip-platform      — platform not supported
#   skip-profile       — profile not supported
#   skip-disabled      — user disabled (or core/non-core handling)
#   skip-not-selected  — --only/$DOTFILES_ENABLED set and this isn't in the list
#   skip-missing-req   — missing required command
_decide_module_action() {
    local name="$1"
    if ! platform_matches "${_MODULES_PLATFORMS[$name]}"; then
        echo "skip-platform"; return
    fi
    if ! profile_matches "${_MODULES_PROFILES[$name]}"; then
        echo "skip-profile"; return
    fi
    local state
    state="$(config_module_state "$name" "${_MODULES_DEFAULT_ENABLED[$name]}")"
    # CLI --only / DOTFILES_ENABLED: only listed modules run.
    if [[ "$state" == "only-other" ]]; then
        echo "skip-not-selected"; return
    fi
    # Disabled = disabled, regardless of core (warning printed by runner).
    if [[ "$state" == "disabled" ]]; then
        echo "skip-disabled"; return
    fi
    local req
    for req in ${_MODULES_REQUIRES[$name]:-}; do
        if ! has "$req"; then
            echo "skip-missing-req:$req"; return
        fi
    done
    echo "run"
}

# Pretty status table — used by `bootstrap.sh --list`.
modules_print_table() {
    local plat prof
    plat="$(platform_tag)"
    prof="$(profile_tag)"
    printf "%sPlatform:%s %s   %sProfile:%s %s\n\n" \
        "$_C_BOLD" "$_C_RESET" "$plat" \
        "$_C_BOLD" "$_C_RESET" "$prof"

    local fmt="  %-20s %-10s %-9s %-13s %s\n"
    # shellcheck disable=SC2059
    printf "$fmt" "MODULE" "STATE" "STATUS" "PLATFORMS" "DESCRIPTION"
    # shellcheck disable=SC2059
    printf "$fmt" "------" "-----" "------" "---------" "-----------"
    local name action status state_label
    for name in "${_MODULES_REGISTRY[@]}"; do
        action="$(_decide_module_action "$name")"
        case "$action" in
            run)               state_label="enabled"  ;;
            skip-platform)     state_label="N/A"      ;;
            skip-profile)      state_label="N/A"      ;;
            skip-disabled)     state_label="disabled" ;;
            skip-not-selected) state_label="off"      ;;
            skip-missing-req*) state_label="blocked"  ;;
        esac
        status="$(modules_status "$name")"
        # shellcheck disable=SC2059
        printf "$fmt" \
            "$name" \
            "$state_label" \
            "$status" \
            "${_MODULES_PLATFORMS[$name]}" \
            "${_MODULES_DESC[$name]}"
    done
}

# Internal: run one module's install.sh (or update.sh if --update).
_run_one() {
    local name="$1"
    local d="${_MODULES_DIR[$name]}"
    local script="install.sh"
    [[ "${_DOTFILES_RUN_MODE:-install}" == "update" && -x "$d/update.sh" ]] && script="update.sh"
    if [[ ! -x "$d/$script" && ! -f "$d/$script" ]]; then
        warn "[$name] no $script — skipping"
        return 0
    fi
    hdr "$name — ${_MODULES_DESC[$name]:-}"
    if (
        export DOTFILES_DIR
        export MODULE_DIR="$d"
        export MODULE_NAME="$name"
        cd "$DOTFILES_DIR"
        bash "$d/$script"
    ); then
        ok "[$name] done"
        return 0
    else
        err "[$name] failed"
        return 1
    fi
}

# modules_run_all — run everything in registry order, respecting deps + filters.
# When --only/DOTFILES_ENABLED is set, narrow the root set to just those.
# Transitive deps are also implicitly selected so they don't get skipped as
# "not selected" by config_module_state.
modules_run_all() {
    if [[ -n "${_DOTFILES_CLI_ONLY:-}${DOTFILES_ENABLED:-}" ]]; then
        local sel="${_DOTFILES_CLI_ONLY:-${DOTFILES_ENABLED:-}}"
        local -a roots=()
        local m
        IFS=',' read -ra _items <<< "$sel"
        for m in "${_items[@]}"; do
            m="${m// /}"
            [[ -n "$m" ]] && roots+=("$m")
        done
        # Expand to transitive deps so they aren't classified as "only-other".
        local ordered
        if ordered="$(_modules_topo_order "${roots[@]}" 2>/dev/null)"; then
            local expanded=""
            while IFS= read -r m; do
                [[ -n "$m" ]] && expanded+="${expanded:+,}$m"
            done <<< "$ordered"
            export _DOTFILES_CLI_ONLY="$expanded"
        fi
        modules_run "${roots[@]}"
    else
        modules_run "${_MODULES_REGISTRY[@]}"
    fi
}

# modules_run <names...>
modules_run() {
    local -a roots=("$@")
    if [[ ${#roots[@]} -eq 0 ]]; then
        warn "no modules to run"
        return 0
    fi
    local ordered
    if ! ordered="$(_modules_topo_order "${roots[@]}")"; then
        return 1
    fi
    local name action req fail_count=0
    declare -A failed_set=()
    while IFS= read -r name; do
        [[ -z "$name" ]] && continue

        # Check if any dep failed earlier
        local dep skipped_due_dep=""
        for dep in ${_MODULES_DEPENDS[$name]:-}; do
            if [[ "${failed_set[$dep]:-}" == "1" ]]; then
                skipped_due_dep="$dep"
                break
            fi
        done
        if [[ -n "$skipped_due_dep" ]]; then
            skip "[$name] dependency '$skipped_due_dep' failed"
            failed_set[$name]=1
            ((fail_count++)) || true
            continue
        fi

        action="$(_decide_module_action "$name")"
        case "$action" in
            run)
                if ! _run_one "$name"; then
                    failed_set[$name]=1
                    ((fail_count++)) || true
                fi
                ;;
            skip-platform)
                skip "[$name] not supported on $(platform_tag) (supported: ${_MODULES_PLATFORMS[$name]})"
                ;;
            skip-profile)
                skip "[$name] not supported on profile '$(profile_tag)' (supported: ${_MODULES_PROFILES[$name]})"
                ;;
            skip-disabled)
                if [[ "${_MODULES_CORE[$name]}" == "true" ]]; then
                    warn "[$name] is core but disabled by user — skipping (your choice, but this may break dependents)"
                else
                    skip "[$name] disabled by user config"
                fi
                ;;
            skip-not-selected)
                # Silent — user already knows what they asked for via --only.
                ;;
            skip-missing-req:*)
                req="${action#skip-missing-req:}"
                warn "[$name] required command '$req' not found — skipping"
                ;;
        esac
    done <<< "$ordered"

    if [[ $fail_count -gt 0 ]]; then
        err "$fail_count module(s) failed"
        return 1
    fi
    return 0
}

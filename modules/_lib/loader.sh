#!/usr/bin/env bash
# Module discovery, validation, dependency resolution, and execution.
#
# Module layout:
#   modules/<name>/
#     module.sh       (required) — manifest, sourced for variables
#     install.sh      (required) — implementation, executed via bash
#     status.sh       (optional) — exits 0 if installed/healthy, 1 if needs install
#     update.sh       (optional) — re-run friendly variant; defaults to install.sh
#     diff.sh         (optional) — preview what install.sh would do (dry-run)
#     uninstall.sh    (optional) — cleanup
#
# Manifest variables (declared in module.sh — all optional except NAME):
#   MODULE_NAME              must match directory name
#   MODULE_DESC              one-line description
#   MODULE_CATEGORY          group label (core|shell|claude|editor|gui|tools|optional)
#   MODULE_PLATFORMS         space-separated: macos linux wsl all  (default: all)
#   MODULE_PROFILES          space-separated: desktop-full server-headless wsl all  (default: all)
#   MODULE_CORE              true|false — core modules cannot be disabled (default: false)
#   MODULE_DEPENDS           space-separated module names that must run first
#   MODULE_REQUIRES          space-separated commands that must exist on PATH
#   MODULE_DEFAULT_ENABLED   true|false — default state if user hasn't decided (default: true)

if [[ "${_DOTFILES_LOADER_LOADED:-}" == "1" ]]; then
    return 0 2>/dev/null || true
fi
_DOTFILES_LOADER_LOADED=1

_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$_LIB_DIR/log.sh"
. "$_LIB_DIR/platform.sh"
. "$_LIB_DIR/config.sh"

declare -ga _MODULES_REGISTRY=()
declare -gA _MODULES_DIR=()
declare -gA _MODULES_DESC=()
declare -gA _MODULES_CATEGORY=()
declare -gA _MODULES_PLATFORMS=()
declare -gA _MODULES_PROFILES=()
declare -gA _MODULES_CORE=()
declare -gA _MODULES_DEPENDS=()
declare -gA _MODULES_REQUIRES=()
declare -gA _MODULES_DEFAULT_ENABLED=()
MODULES_DIR=""

# Category display order (modules of unknown categories appear after these in alpha).
_CATEGORY_ORDER=(core shell claude editor gui tools optional)

# Last-run state lives under XDG_STATE_HOME so the dotfiles repo stays clean.
_RUN_STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/runs"

modules_init() {
    MODULES_DIR="${1:-${MODULES_DIR:-$DOTFILES_DIR/modules}}"
    if [[ ! -d "$MODULES_DIR" ]]; then
        err "modules dir not found: $MODULES_DIR"
        return 1
    fi
    mkdir -p "$_RUN_STATE_DIR" 2>/dev/null || true
}

_source_manifest() {
    local manifest="$1"
    unset MODULE_NAME MODULE_DESC MODULE_CATEGORY MODULE_PLATFORMS MODULE_PROFILES \
          MODULE_CORE MODULE_DEPENDS MODULE_REQUIRES MODULE_DEFAULT_ENABLED
    . "$manifest"
}

modules_discover() {
    [[ -n "$MODULES_DIR" ]] || modules_init
    _MODULES_REGISTRY=()
    local d name manifest
    for d in "$MODULES_DIR"/*/; do
        [[ -d "$d" ]] || continue
        name="$(basename "$d")"
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
            warn "module dir '$name' declares MODULE_NAME='$MODULE_NAME' — using '$name'"
        fi
        _MODULES_REGISTRY+=("$name")
        _MODULES_DIR[$name]="$d"
        _MODULES_DESC[$name]="${MODULE_DESC:-}"
        _MODULES_CATEGORY[$name]="${MODULE_CATEGORY:-optional}"
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

# modules_last_run <name> — echoes timestamp like "2026-05-08 14:53" or "never"
modules_last_run() {
    local name="$1"
    local f="$_RUN_STATE_DIR/$name"
    if [[ -f "$f" ]]; then
        if has stat; then
            stat -c '%y' "$f" 2>/dev/null | cut -d'.' -f1 \
                || stat -f '%Sm' -t '%Y-%m-%d %H:%M:%S' "$f" 2>/dev/null \
                || date -r "$f" '+%Y-%m-%d %H:%M:%S' 2>/dev/null \
                || echo "?"
        else
            echo "?"
        fi
    else
        echo "never"
    fi
}

# Topological order. Echoes deps before dependents.
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

# Modules that depend (directly) on $1. Always returns 0.
_modules_dependents() {
    local target="$1" name dep
    for name in "${_MODULES_REGISTRY[@]}"; do
        for dep in ${_MODULES_DEPENDS[$name]:-}; do
            if [[ "$dep" == "$target" ]]; then
                echo "$name"
            fi
        done
    done
    return 0
}

# Decide what should happen with this module on the current machine.
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
    if [[ "$state" == "only-other" ]]; then
        echo "skip-not-selected"; return
    fi
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

# ---------- Color helpers (used by --list and --info) ----------

_color_state() {
    case "$1" in
        enabled)  printf "%s%-9s%s" "$_C_GREEN"  "$1" "$_C_RESET" ;;
        disabled) printf "%s%-9s%s" "$_C_DIM"    "$1" "$_C_RESET" ;;
        off)      printf "%s%-9s%s" "$_C_DIM"    "$1" "$_C_RESET" ;;
        N/A)      printf "%s%-9s%s" "$_C_RED"    "$1" "$_C_RESET" ;;
        blocked)  printf "%s%-9s%s" "$_C_YELLOW" "$1" "$_C_RESET" ;;
        *)        printf "%-9s" "$1" ;;
    esac
}

_color_status() {
    case "$1" in
        clean)    printf "%s%-9s%s" "$_C_GREEN"  "$1" "$_C_RESET" ;;
        dirty)    printf "%s%-9s%s" "$_C_YELLOW" "$1" "$_C_RESET" ;;
        unknown)  printf "%s%-9s%s" "$_C_DIM"    "$1" "$_C_RESET" ;;
        missing)  printf "%s%-9s%s" "$_C_RED"    "$1" "$_C_RESET" ;;
        *)        printf "%-9s" "$1" ;;
    esac
}

# Visible-character-aware truncate-to-fit (we color the cells, so column widths
# include ANSI escapes; using straight printf %-Ns would over/under pad).
# Helper: no-op for now — colors are applied by the dedicated _color_* fns
# whose output is exactly N visible chars wide.

# Pretty-print the module table grouped by category.
modules_print_table() {
    local plat prof
    plat="$(platform_tag)"
    prof="$(profile_tag)"
    printf "%sPlatform:%s %s   %sProfile:%s %s\n\n" \
        "$_C_BOLD" "$_C_RESET" "$plat" \
        "$_C_BOLD" "$_C_RESET" "$prof"

    # Header
    printf "  %s%-18s %-9s %-9s %-15s %s%s\n" \
        "$_C_DIM" "MODULE" "STATE" "STATUS" "PLATFORMS" "DESCRIPTION" "$_C_RESET"

    # Bucket modules by category preserving registry order within each bucket.
    declare -A bucket
    local name cat
    for name in "${_MODULES_REGISTRY[@]}"; do
        cat="${_MODULES_CATEGORY[$name]:-optional}"
        bucket[$cat]+="$name "
    done

    # Walk known categories first, then any unrecognized buckets alphabetically.
    local -a known=("${_CATEGORY_ORDER[@]}") leftover=()
    for c in "${!bucket[@]}"; do
        local found=0
        for k in "${known[@]}"; do [[ "$k" == "$c" ]] && { found=1; break; }; done
        [[ "$found" == "0" ]] && leftover+=("$c")
    done
    if [[ ${#leftover[@]} -gt 0 ]]; then
        IFS=$'\n' leftover=($(printf "%s\n" "${leftover[@]}" | sort))
    fi

    local action status state_label state_color status_color
    for c in "${known[@]}" "${leftover[@]}"; do
        [[ -z "${bucket[$c]:-}" ]] && continue
        printf "\n  %s%s── %s ──%s\n" "$_C_BOLD" "$_C_MAGENTA" "$c" "$_C_RESET"
        for name in ${bucket[$c]}; do
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
            state_color="$(_color_state "$state_label")"
            status_color="$(_color_status "$status")"
            printf "  %-18s %s %s %-15s %s\n" \
                "$name" "$state_color" "$status_color" \
                "${_MODULES_PLATFORMS[$name]}" \
                "${_MODULES_DESC[$name]}"
        done
    done
    echo
}

# Detail view: bootstrap.sh --info <name>
modules_info() {
    local name="$1"
    if [[ -z "${_MODULES_DIR[$name]:-}" ]]; then
        err "unknown module: $name"
        return 1
    fi
    local action status last_run state_label
    action="$(_decide_module_action "$name")"
    status="$(modules_status "$name")"
    last_run="$(modules_last_run "$name")"

    case "$action" in
        run)               state_label="enabled"  ;;
        skip-platform)     state_label="N/A on $(platform_tag) (supports: ${_MODULES_PLATFORMS[$name]})" ;;
        skip-profile)      state_label="N/A on profile '$(profile_tag)' (supports: ${_MODULES_PROFILES[$name]})" ;;
        skip-disabled)     state_label="disabled by user config" ;;
        skip-not-selected) state_label="not in --only / DOTFILES_ENABLED list" ;;
        skip-missing-req:*) state_label="blocked: missing '${action#skip-missing-req:}' on PATH" ;;
    esac

    # Resolve transitive deps + dependents (tolerate empty output under set -e).
    local deps_transitive dependents
    deps_transitive="$(_modules_topo_order "$name" 2>/dev/null \
        | { grep -v "^${name}$" || true; } \
        | tr '\n' ' ' | sed 's/ $//')"
    dependents="$(_modules_dependents "$name" | tr '\n' ' ' | sed 's/ $//')"

    printf "%s%s%s\n" "$_C_BOLD" "$name" "$_C_RESET"
    printf "  %s\n\n" "${_MODULES_DESC[$name]}"
    printf "  %scategory:%s     %s\n" "$_C_DIM" "$_C_RESET" "${_MODULES_CATEGORY[$name]}"
    printf "  %splatforms:%s    %s\n" "$_C_DIM" "$_C_RESET" "${_MODULES_PLATFORMS[$name]}"
    printf "  %sprofiles:%s     %s\n" "$_C_DIM" "$_C_RESET" "${_MODULES_PROFILES[$name]}"
    printf "  %score:%s         %s\n" "$_C_DIM" "$_C_RESET" "${_MODULES_CORE[$name]}"
    printf "  %sdefault:%s      %s\n" "$_C_DIM" "$_C_RESET" "${_MODULES_DEFAULT_ENABLED[$name]}"
    printf "  %sdepends on:%s   %s\n" "$_C_DIM" "$_C_RESET" "${deps_transitive:-(none)}"
    printf "  %sdepended by:%s  %s\n" "$_C_DIM" "$_C_RESET" "${dependents:-(none)}"
    printf "  %srequires:%s     %s\n" "$_C_DIM" "$_C_RESET" "${_MODULES_REQUIRES[$name]:-(none)}"
    printf "\n"
    printf "  %sstate:%s        %s\n" "$_C_DIM" "$_C_RESET" "$state_label"
    printf "  %sstatus:%s       %s\n" "$_C_DIM" "$_C_RESET" "$status"
    printf "  %slast run:%s     %s\n" "$_C_DIM" "$_C_RESET" "$last_run"
    printf "  %smodule dir:%s   %s\n" "$_C_DIM" "$_C_RESET" "${_MODULES_DIR[$name]}"
    printf "\n"

    # Hints
    if [[ "$action" == "skip-disabled" ]]; then
        printf "  %sto enable:%s    bootstrap.sh --only=%s   (or remove '!' line in modules.conf)\n" \
            "$_C_DIM" "$_C_RESET" "$name"
    elif [[ "$action" == "skip-not-selected" ]]; then
        printf "  %sto run:%s       include in --only=  list, or run without --only\n" \
            "$_C_DIM" "$_C_RESET"
    elif [[ "$action" == "run" ]]; then
        printf "  %sto run:%s       bootstrap.sh --only=%s\n" \
            "$_C_DIM" "$_C_RESET" "$name"
    fi
    printf "  %sto preview:%s   bootstrap.sh --diff=%s\n" "$_C_DIM" "$_C_RESET" "$name"
    echo
}

# Dry-run preview: bootstrap.sh --diff <name>
modules_diff() {
    local name="$1"
    local d="${_MODULES_DIR[$name]:-}"
    if [[ -z "$d" ]]; then
        err "unknown module: $name"
        return 1
    fi
    hdr "$name — preview"
    if [[ -x "$d/diff.sh" ]]; then
        export DOTFILES_DIR MODULE_DIR="$d" MODULE_NAME="$name"
        bash "$d/diff.sh"
        return $?
    fi
    # Fallback: print the install script. Use bat for syntax highlighting if available.
    info "no dedicated diff.sh — showing install.sh source (would be executed):"
    echo
    if has bat; then
        bat --style=plain --paging=never --language=bash "$d/install.sh"
    elif has batcat; then
        batcat --style=plain --paging=never --language=bash "$d/install.sh"
    else
        cat "$d/install.sh"
    fi
}

# ---------- Run ----------

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
        # Record successful run timestamp
        mkdir -p "$_RUN_STATE_DIR" 2>/dev/null || true
        : > "$_RUN_STATE_DIR/$name" 2>/dev/null || true
        return 0
    else
        err "[$name] failed"
        return 1
    fi
}

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

# ---------- Reset / uninstall ----------

# Run a module's uninstall.sh if it has one. Honors UNLINK_DRY_RUN env.
_uninstall_one() {
    local name="$1"
    local d="${_MODULES_DIR[$name]}"
    if [[ ! -f "$d/uninstall.sh" ]]; then
        skip "[$name] no uninstall.sh — leaving alone"
        return 0
    fi
    hdr "$name — reset"
    if (
        export DOTFILES_DIR
        export MODULE_DIR="$d"
        export MODULE_NAME="$name"
        cd "$DOTFILES_DIR"
        bash "$d/uninstall.sh"
    ); then
        ok "[$name] reset done"
        return 0
    else
        err "[$name] reset failed"
        return 1
    fi
}

# modules_reset [name ...]
# With no args: reset every discovered module that has an uninstall.sh, in
# REVERSE topological order (dependents before dependencies).
# With args: reset only those modules (still reverse topo of the union).
modules_reset() {
    local -a roots=()
    if [[ $# -gt 0 ]]; then
        roots=("$@")
    else
        roots=("${_MODULES_REGISTRY[@]}")
    fi
    local ordered
    if ! ordered="$(_modules_topo_order "${roots[@]}")"; then
        return 1
    fi
    # Reverse the topo order.
    local -a reversed=()
    while IFS= read -r m; do
        [[ -n "$m" ]] && reversed=("$m" "${reversed[@]}")
    done <<< "$ordered"

    local fail_count=0 n
    for n in "${reversed[@]}"; do
        _uninstall_one "$n" || ((fail_count++)) || true
    done
    if [[ $fail_count -gt 0 ]]; then
        err "$fail_count module(s) failed to reset"
        return 1
    fi
    return 0
}

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
                    warn "[$name] is core but disabled by user — skipping (your choice, may break dependents)"
                else
                    skip "[$name] disabled by user config"
                fi
                ;;
            skip-not-selected)
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

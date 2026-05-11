#!/usr/bin/env bash
# =============================================================================
# bootstrap.sh — module-driven dotfiles provisioner
# =============================================================================
# Discovers modules in modules/, filters by platform/profile/user-config,
# resolves dependencies, runs them in order. Idempotent + safe to re-run.
#
# Usage:
#   ./bootstrap.sh                       # full install (all enabled modules)
#   ./bootstrap.sh --update              # git pull + re-run all enabled
#   ./bootstrap.sh --list                # show module table (state + status)
#   ./bootstrap.sh --status              # alias for --list
#   ./bootstrap.sh --info=NAME           # detailed view of one module
#   ./bootstrap.sh --diff=NAME           # preview what NAME would do
#   ./bootstrap.sh --only=mod1,mod2      # run only these modules (+ their deps)
#   ./bootstrap.sh --skip=mod1,mod2      # run all except these
#   ./bootstrap.sh --doctor [--fix]      # diagnostic only, no changes
#   ./bootstrap.sh --profile=NAME        # override detected profile
#
# Backward-compat (legacy flags):
#   --link-only      → --only=symlinks
#   --packages-only  → --only=packages
#   --mcp-only       → --only=python-tools,ssh-superbro,mcp-servers
#
# Environment overrides:
#   PROFILE=...                         override detected profile
#   DOTFILES_ENABLED="m1,m2"            run only these modules (= --only)
#   DOTFILES_DISABLED="m1,m2"           skip these modules (= --skip)
#   DOTFILES_QUIET=1                    suppress non-warn output
#
# Per-machine config: ~/.config/dotfiles/modules.conf
#   one module per line, prefix "!" to disable
# =============================================================================

# Require bash 4+ (declare -g, associative arrays). macOS ships 3.2.
if (( BASH_VERSINFO[0] < 4 )); then
    for _candidate in /opt/homebrew/bin/bash /usr/local/bin/bash /home/linuxbrew/.linuxbrew/bin/bash; do
        if [[ -x "$_candidate" ]]; then
            exec "$_candidate" "$0" "$@"
        fi
    done
    echo "Error: bash 4+ required, found $BASH_VERSION. Install: brew install bash" >&2
    exit 1
fi

set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export DOTFILES_DIR

# Make Homebrew available in PATH (script runs as plain bash).
for _brew_bin in /opt/homebrew/bin/brew /usr/local/bin/brew /home/linuxbrew/.linuxbrew/bin/brew; do
    if [[ -x "$_brew_bin" ]]; then
        eval "$("$_brew_bin" shellenv)"
        break
    fi
done
unset _brew_bin

# Load module system.
. "$DOTFILES_DIR/modules/_lib/log.sh"
. "$DOTFILES_DIR/modules/_lib/platform.sh"
. "$DOTFILES_DIR/modules/_lib/config.sh"
. "$DOTFILES_DIR/modules/_lib/loader.sh"

# -----------------------------------------------------------------------------
# Argument parsing
# -----------------------------------------------------------------------------
MODE="full"           # full | update | list | doctor | info | diff
FIX_FLAG=""
ONLY=""
SKIP=""
INFO_TARGET=""
DIFF_TARGET=""

# Legacy aliases collected here so we can apply them after parsing.
_LEGACY_ONLY=""

print_help() {
    grep -E '^# ' "$0" | sed 's/^# //'
}

for arg in "$@"; do
    case "$arg" in
        --update|-u)        MODE="update" ;;
        --list)             MODE="list" ;;
        --status)           MODE="list" ;;
        --info=*)           MODE="info"; INFO_TARGET="${arg#--info=}" ;;
        --diff=*)           MODE="diff"; DIFF_TARGET="${arg#--diff=}" ;;
        --doctor)           MODE="doctor" ;;
        --fix)              FIX_FLAG="--fix" ;;
        --only=*)           ONLY="${arg#--only=}" ;;
        --skip=*)           SKIP="${arg#--skip=}" ;;
        --link-only)        _LEGACY_ONLY="symlinks" ;;
        --packages-only)    _LEGACY_ONLY="packages" ;;
        --mcp-only)         _LEGACY_ONLY="python-tools,ssh-superbro,mcp-servers" ;;
        --profile=*)        export PROFILE="${arg#--profile=}" ;;
        -h|--help)          print_help; exit 0 ;;
        *)                  err "unknown arg: $arg"; print_help; exit 2 ;;
    esac
done

if [[ -n "$_LEGACY_ONLY" && -z "$ONLY" ]]; then
    ONLY="$_LEGACY_ONLY"
fi

# Pass --only / --skip to the loader via env.
[[ -n "$ONLY" ]] && export _DOTFILES_CLI_ONLY="$ONLY"
[[ -n "$SKIP" ]] && export _DOTFILES_CLI_SKIP="$SKIP"
[[ "$MODE" == "update" ]] && export _DOTFILES_RUN_MODE="update"

# -----------------------------------------------------------------------------
# Run
# -----------------------------------------------------------------------------
modules_init
modules_discover

case "$MODE" in
    list)
        modules_print_table
        ;;
    info)
        modules_info "$INFO_TARGET"
        ;;
    diff)
        modules_diff "$DIFF_TARGET"
        ;;
    doctor)
        if [[ -x "$DOTFILES_DIR/scripts/doctor.sh" ]]; then
            bash "$DOTFILES_DIR/scripts/doctor.sh" $FIX_FLAG
        else
            warn "scripts/doctor.sh not present"
            exit 1
        fi
        ;;
    update)
        log "git pull --rebase --autostash …"
        (cd "$DOTFILES_DIR" && git pull --rebase --autostash) || warn "git pull failed (non-fatal)"
        log "OS: $(uname -s)  platform: $(platform_tag)  profile: $(profile_tag)  host: $(hostname -s 2>/dev/null || hostname)"
        modules_run_all
        if [[ -x "$DOTFILES_DIR/scripts/doctor.sh" ]]; then
            bash "$DOTFILES_DIR/scripts/doctor.sh" $FIX_FLAG || true
        fi
        ok "update complete (profile: $(profile_tag))"
        ;;
    full)
        log "OS: $(uname -s)  platform: $(platform_tag)  profile: $(profile_tag)  host: $(hostname -s 2>/dev/null || hostname)"
        modules_run_all
        if [[ -x "$DOTFILES_DIR/scripts/doctor.sh" ]]; then
            bash "$DOTFILES_DIR/scripts/doctor.sh" $FIX_FLAG || true
        fi
        ok "bootstrap complete (profile: $(profile_tag))"
        ;;
esac

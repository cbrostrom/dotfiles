#!/usr/bin/env bash
# Shared logging primitives for the module system.
# All output uses these so a module can be silenced via DOTFILES_QUIET=1.

if [[ "${_DOTFILES_LOG_LOADED:-}" == "1" ]]; then
    return 0 2>/dev/null || true
fi
_DOTFILES_LOG_LOADED=1

if [[ -t 1 ]]; then
    _C_RESET=$'\033[0m'
    _C_DIM=$'\033[2m'
    _C_RED=$'\033[0;31m'
    _C_GREEN=$'\033[0;32m'
    _C_YELLOW=$'\033[1;33m'
    _C_BLUE=$'\033[0;34m'
    _C_CYAN=$'\033[0;36m'
    _C_MAGENTA=$'\033[0;35m'
    _C_BOLD=$'\033[1m'
else
    _C_RESET="" _C_DIM="" _C_RED="" _C_GREEN="" _C_YELLOW=""
    _C_BLUE="" _C_CYAN="" _C_MAGENTA="" _C_BOLD=""
fi

# Single-line logs. All write to stdout except err which goes to stderr.
log()    { [[ "${DOTFILES_QUIET:-0}" == "1" ]] || printf "%s[bootstrap]%s %s\n" "$_C_BLUE"    "$_C_RESET" "$*"; }
ok()     { [[ "${DOTFILES_QUIET:-0}" == "1" ]] || printf "%s[ ok ]%s %s\n"     "$_C_GREEN"   "$_C_RESET" "$*"; }
warn()   { printf "%s[warn]%s %s\n"   "$_C_YELLOW"  "$_C_RESET" "$*"; }
err()    { printf "%s[err ]%s %s\n"   "$_C_RED"     "$_C_RESET" "$*" >&2; }
info()   { [[ "${DOTFILES_QUIET:-0}" == "1" ]] || printf "%s[info]%s %s\n"     "$_C_CYAN"    "$_C_RESET" "$*"; }
skip()   { [[ "${DOTFILES_QUIET:-0}" == "1" ]] || printf "%s[skip]%s %s\n"     "$_C_DIM"     "$_C_RESET" "$*"; }

# Headers and dividers used by the runner.
hdr() {
    [[ "${DOTFILES_QUIET:-0}" == "1" ]] && return 0
    printf "\n%s%s═══ %s ═══%s\n" "$_C_BOLD" "$_C_MAGENTA" "$*" "$_C_RESET"
}

dim() { [[ "${DOTFILES_QUIET:-0}" == "1" ]] || printf "%s%s%s\n" "$_C_DIM" "$*" "$_C_RESET"; }

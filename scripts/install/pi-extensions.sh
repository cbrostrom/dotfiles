#!/usr/bin/env bash
# =============================================================================
# scripts/install/pi-extensions.sh — install and update pi extensions
# =============================================================================
# Reads the manifest in pi-extensions.txt and makes the local machine match it:
#   - git: entries are cloned/updated via `pi install` or `git pull --ff-only`
#   - npm: entries are installed/updated via `pi install npm:<name>`
# Puppet-free, cron-free: run manually, from bootstrap, or after adding a line.
#
# Usage:
#   pi-extensions.sh                 # process the whole manifest
#   pi-extensions.sh <spec>          # single entry, e.g. npm:@gotgenes/pi-subagents
#
# Never force-updates: git conflicts are reported and skipped.
# =============================================================================

set -uo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
MANIFEST="$DOTFILES_DIR/scripts/install/pi-extensions.txt"
PI_AGENT_DIR="$HOME/.pi/agent"

if ! command -v pi >/dev/null 2>&1; then
    if [[ -x "$DOTFILES_DIR/scripts/pi" ]]; then
        PI_BIN="$DOTFILES_DIR/scripts/pi"
    else
        echo "pi: not found on PATH and no shim in dotfiles" >&2
        exit 1
    fi
else
    PI_BIN="pi"
fi

failures=0
updated=0

msg()  { printf '  %s\n' "$*"; }
fail() { ((failures++)) || true; printf '  ✗ %s\n' "$*"; }

# npm: entry — name lives after the prefix; scoped names keep their slash.
install_npm() {
    local name="$1"
    if [[ -f "$PI_AGENT_DIR/npm/node_modules/$name/package.json" ]]; then
        if "$PI_BIN" install "npm:$name" >/dev/null 2>&1; then
            msg "updated: $name"
            updated=$((updated + 1))
        else
            fail "update failed: $name (kept previous version)"
        fi
    else
        if "$PI_BIN" install "npm:$name" >/dev/null 2>&1; then
            msg "installed: $name"
            updated=$((updated + 1))
        else
            fail "install failed: $name"
        fi
    fi
}

# git: entry — path after the prefix, e.g. github.com/owner/repo
process_git() {
    local spec="$1" path specdir
    path="${spec#git:}"
    specdir="$PI_AGENT_DIR/git/$path"
    if [[ ! -d "$specdir/.git" ]]; then
        if "$PI_BIN" install "$spec" >/dev/null 2>&1; then
            msg "installed: $spec"
            updated=$((updated + 1))
        else
            fail "install failed: $spec"
        fi
        return
    fi
    if git -C "$specdir" pull --ff-only >>"$specdir/.pi-ext-update.log" 2>&1; then
        local behind
        behind="$(git -C "$specdir" log --oneline HEAD@{1}..HEAD 2>/dev/null | wc -l | tr -d ' ')"
        if [[ "$behind" -gt 0 ]]; then
            msg "updated: $spec (+${behind} commits)"
            updated=$((updated + 1))
        else
            msg "unchanged: $spec"
        fi
    else
        fail "update skipped: $spec (git conflict, kept clone; see .pi-ext-update.log)"
    fi
    if [[ -f "$specdir/package.json" ]]; then
        (cd "$specdir" && npm install --ignore-scripts --silent) \
            || fail "dependency install failed: $spec"
    fi
}

process_entry() {
    local spec="$1"
    case "$spec" in
        git:*) process_git "$spec" ;;
        npm:*)
            install_npm "${spec#npm:}"
            ;;
        *)
            fail "unknown spec format: $spec (expected npm:<name> or git:...)"
            ;;
    esac
}

if [[ $# -gt 0 ]]; then
    echo "pi-extensions: single spec mode"
    process_entry "$1"
else
    if [[ ! -f "$MANIFEST" ]]; then
        echo "pi-extensions: manifest missing: $MANIFEST" >&2
        exit 1
    fi
    while IFS= read -r line; do
        line="${line%%#*}"
        line="$(echo "$line" | tr -d '[:space:]')"
        [[ -z "$line" ]] && continue
        process_entry "$line"
    done < "$MANIFEST"
fi

echo
echo "pi-extensions: $updated processed, $failures failure(s)"
exit $((failures > 0 ? 1 : 0))

#!/usr/bin/env bash
# Regenerate ~/.project-farm/ symlink farm.
# Re-exec with bash 4+ if needed (macOS ships bash 3.2).
if (( BASH_VERSINFO[0] < 4 )); then
    for _b in /opt/homebrew/bin/bash /usr/local/bin/bash; do
        [[ -x "$_b" ]] && exec "$_b" "$0" "$@"
    done
    echo "${0##*/}: bash 4+ required" >&2; exit 1
fi
#
# Each git repo under ~/Projects/{clients,internal,personal,sandbox}
# becomes a symlink in the flat farm. Naming:
#   clients/<client>/<repo>  → <client>-<repo>
#   internal/<repo>          → <repo>     (or int-<repo> on collision)
#   personal/<repo>          → <repo>
#   sandbox/<repo>           → sb-<repo>
#
# Extra paths from symlink.config are also linked.
#
# Usage:
#   sync-symlinks.sh             # regenerate
#   sync-symlinks.sh --dry-run   # preview only

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

require_cmd fd

DRY_RUN=0
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=1

CONFIG_FILE="$SCRIPT_DIR/symlink.config"

mkdir -p "$SYMLINK_ROOT"

# Wipe existing symlinks (keep real files/dirs in case user added them)
log "Pruning existing symlinks in $SYMLINK_ROOT"
removed=0
while IFS= read -r link; do
    [[ -L "$link" ]] || continue
    [[ $DRY_RUN -eq 0 ]] && rm "$link"
    removed=$((removed+1))
done < <(find "$SYMLINK_ROOT" -mindepth 1 -maxdepth 1 -type l 2>/dev/null)
log "  removed $removed old symlinks"

declare -A USED_NAMES
created=0
collisions=0

make_link() {
    local target="$1" name="$2"
    if [[ -n "${USED_NAMES[$name]:-}" ]]; then
        warn "collision: $name (already → ${USED_NAMES[$name]}, skipping $target)"
        collisions=$((collisions+1))
        return
    fi
    USED_NAMES[$name]="$target"
    if [[ $DRY_RUN -eq 1 ]]; then
        printf '  %s → %s\n' "$name" "$target"
    else
        ln -sfn "$target" "$SYMLINK_ROOT/$name"
        printf '  %s%s%s → %s\n' "$C_GRN" "$name" "$C_RST" "$target"
    fi
    created=$((created+1))
}

# Find a repo's parent category from its absolute path
process_repo() {
    local repo_abs="$1"
    local rel="${repo_abs#"$PROJECTS_ROOT/"}"
    local parts segments=()
    IFS='/' read -ra segments <<< "$rel"

    local name=""
    case "${segments[0]}" in
        clients)
            if [[ ${#segments[@]} -ge 3 ]]; then
                name="${segments[1]}-${segments[-1]}"
            else
                name="${segments[-1]}"
            fi
            ;;
        internal)
            name="${segments[-1]}"
            ;;
        personal)
            name="${segments[-1]}"
            ;;
        sandbox)
            name="sb-${segments[-1]}"
            ;;
        *)
            name="${segments[-1]}"
            ;;
    esac

    make_link "$repo_abs" "$name"
}

log "Scanning repos under $PROJECTS_ROOT/{clients,internal,personal,sandbox}"
while IFS= read -r repo; do
    [[ -d "$repo" ]] || continue
    process_repo "$repo"
done < <(
    for cat in clients internal personal sandbox; do
        [[ -d "$PROJECTS_ROOT/$cat" ]] || continue
        # Find dirs that contain a .git (depth-limited to keep submodules out)
        fd -t d -H -d 4 '^\.git$' "$PROJECTS_ROOT/$cat" 2>/dev/null \
            | sed 's|/\.git/*$||' | sort -u
    done
)

# Extra paths from config
if [[ -f "$CONFIG_FILE" ]]; then
    log "Adding extra paths from $CONFIG_FILE"
    while IFS= read -r line; do
        line="${line%%#*}"
        line="$(echo "$line" | awk '{$1=$1; print}')"
        [[ -z "$line" ]] && continue
        # Expand ~
        eval expanded="$line"
        if [[ -d "$expanded" ]]; then
            make_link "$expanded" "$(basename "$expanded")"
        else
            warn "extra path missing: $expanded"
        fi
    done < "$CONFIG_FILE"
fi

ok "Created $created symlinks ($collisions collisions)"
[[ $DRY_RUN -eq 1 ]] && warn "Dry-run only. Re-run without --dry-run to apply."

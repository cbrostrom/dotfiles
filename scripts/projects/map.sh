#!/usr/bin/env bash
# kb map dispatcher — routes subcommands to scripts/projects/map-*.sh
#
# Usage: kb map <subcommand> [args]
#   scan [--refresh-inventory]          Refresh registry
#   list [--type=...] [--brain] [--no-codebase]
#   codebase [path|slug] [--all] [--missing-only] [--force]
#   init <slug>
#   doctor

set -euo pipefail

# Re-exec with bash 4+ if the shebang resolved to /bin/bash (3.2 on macOS).
if (( BASH_VERSINFO[0] < 4 )); then
    for _b in /opt/homebrew/bin/bash /usr/local/bin/bash; do
        [[ -x "$_b" ]] && exec "$_b" "$0" "$@"
    done
    echo "${0##*/}: bash 4+ required (found $BASH_VERSION)" >&2; exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

_run() {
    local script="$SCRIPT_DIR/$1"
    shift
    if [[ ! -f "$script" ]]; then
        echo "kb map: subcommand not yet implemented (missing $script)" >&2
        exit 1
    fi
    exec "$BASH" "$script" "$@"
}

cmd="${1:-help}"
shift 2>/dev/null || true

case "$cmd" in
    scan)     _run map-scan.sh    "$@" ;;
    list)     _run map-list.sh    "$@" ;;
    codebase) _run map-codebase.sh "$@" ;;
    init)     _run map-init.sh    "$@" ;;
    doctor)   _run map-doctor.sh  "$@" ;;
    help|-h|--help)
        cat <<'EOF'
kb map — project registry and CODEBASE generator

Usage: kb map <subcommand> [args]

  scan [--refresh-inventory]
        Write/update personal/projects-registry.md. Reuses _inventory.json
        if <24h old unless --refresh-inventory is passed.

  list [--type=work-client|work-shopify|...] [--brain] [--no-codebase]
        Filtered table from registry (no rescan).

  codebase [path|slug] [--all] [--missing-only] [--force]
        Generate CODEBASE.md skeleton. Skips existing by default.

  init <slug>
        Promote registry entry to active project brain (kb init <slug>).

  doctor
        AI setup audit — read-only report, no mutations.

Config: ~/dotfiles/config/projects-map.conf
EOF
        ;;
    *)
        echo "kb map: unknown subcommand '$cmd'. Run: kb map help" >&2
        exit 1
        ;;
esac

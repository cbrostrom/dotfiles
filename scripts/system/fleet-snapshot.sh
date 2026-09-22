#!/usr/bin/env bash
# Collect machine snapshots from reachable fleet hosts via SSH.
# Usage: ./scripts/system/fleet-snapshot.sh [output-dir]
# Default output: stdout summary; with output-dir writes one file per host.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
FLEET_CONF="$DOTFILES_DIR/config/fleet-hosts.conf"
SNAPSHOT="$DOTFILES_DIR/scripts/system/machine-snapshot.sh"
OUT_DIR="${1:-}"

if [[ ! -f "$FLEET_CONF" ]]; then
    echo "fleet config missing: $FLEET_CONF" >&2
    exit 1
fi

# shellcheck source=config/fleet-hosts.conf
source "$FLEET_CONF"

[[ -n "$OUT_DIR" ]] && mkdir -p "$OUT_DIR"

for entry in "${FLEET_SSH[@]}"; do
    IFS='|' read -r name _address _port _user _profile _role _push _paseo _notes <<<"$entry"

    if [[ "$name" == "mac" ]]; then
        if [[ -x "$SNAPSHOT" ]]; then
            if [[ -n "$OUT_DIR" ]]; then
                "$SNAPSHOT" >"$OUT_DIR/${name}.md"
                echo "wrote $OUT_DIR/${name}.md"
            else
                echo "=== $name (local) ==="
                "$SNAPSHOT" | head -20
            fi
        fi
        continue
    fi

    if ! ssh -o ConnectTimeout=5 -o BatchMode=yes "$name" true 2>/dev/null; then
        echo "skip $name (unreachable)" >&2
        continue
    fi

    if [[ -n "$OUT_DIR" ]]; then
        ssh "$name" "bash -s" <"$SNAPSHOT" >"$OUT_DIR/${name}.md"
        echo "wrote $OUT_DIR/${name}.md"
    else
        echo "=== $name ==="
        ssh "$name" "bash -s" <"$SNAPSHOT" | head -20
    fi
done

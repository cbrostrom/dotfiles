#!/usr/bin/env bash
# Update zellij-sessionizer root_dirs in config.kdl to point to the symlink farm.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

[[ -f "$ZELLIJ_CONFIG" ]] || { warn "Zellij config not found: $ZELLIJ_CONFIG"; exit 0; }

target="$SYMLINK_ROOT"

if grep -q 'zellij-sessionizer' "$ZELLIJ_CONFIG"; then
    log "Updating root_dirs in $ZELLIJ_CONFIG → $target"
    # Match: root_dirs "..."   inside the sessionizer block.
    # We do an in-place edit on the first root_dirs line after the sessionizer plugin URL.
    perl -i -pe '
        BEGIN { $in_block = 0 }
        if (/zellij-sessionizer/) { $in_block = 1 }
        if ($in_block && /root_dirs\s+"[^"]*"/) {
            s|root_dirs\s+"[^"]*"|root_dirs "'"$target"'"|;
            $in_block = 0;
        }
    ' "$ZELLIJ_CONFIG"
    ok "Updated"
else
    warn "No zellij-sessionizer keybind found in $ZELLIJ_CONFIG; skipping."
fi

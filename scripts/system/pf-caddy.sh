#!/usr/bin/env bash
# Ensure Caddy pf anchor is wired into /etc/pf.conf so that
# https://*.local (port 443) redirects to Caddy on port 8443.
# Safe to run multiple times — idempotent.
#
# Usage: sudo ./scripts/system/pf-caddy.sh
# Auto-run: add to a LaunchDaemon if you want it at boot.

set -euo pipefail

PF_CONF="/etc/pf.conf"
ANCHOR_FILE="/etc/pf.anchors/caddy.local"
ANCHOR_NAME="caddy.local"

if [[ $(id -u) -ne 0 ]]; then
    echo "Must run as root: sudo $0" >&2
    exit 1
fi

# Write anchor rule if missing
if [[ ! -f "$ANCHOR_FILE" ]]; then
    cat > "$ANCHOR_FILE" << 'ANCHOR'
rdr pass on lo0 inet proto tcp from any to any port 443 -> 127.0.0.1 port 8443
ANCHOR
    echo "Created $ANCHOR_FILE"
fi

# Wire anchor into pf.conf if not already present (idempotent)
if ! grep -q "rdr-anchor \"${ANCHOR_NAME}\"" "$PF_CONF"; then
    # Insert rdr-anchor before dummynet-anchor (translation must precede filter)
    sed -i '' "s|dummynet-anchor \"com.apple/\*\"|rdr-anchor \"${ANCHOR_NAME}\"\ndummynet-anchor \"com.apple/*\"|" "$PF_CONF"
    echo "Added rdr-anchor to $PF_CONF"
fi

if ! grep -q "load anchor \"${ANCHOR_NAME}\"" "$PF_CONF"; then
    # Append load directive after com.apple load
    sed -i '' "s|load anchor \"com.apple\" from.*|&\nload anchor \"${ANCHOR_NAME}\" from \"${ANCHOR_FILE}\"|" "$PF_CONF"
    echo "Added load directive to $PF_CONF"
fi

pfctl -f "$PF_CONF" 2>&1 | grep -v "No ALTQ\|ALTQ related\|Use of -f" || true
echo "pf rules loaded — https://*.local now resolves without port"

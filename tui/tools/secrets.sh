#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

echo
gum style --bold --foreground 220 "TOOLS › SECRETS"
echo

SECRETS_FILE="$HOME/.local-secrets"

if [[ ! -f "$SECRETS_FILE" ]]; then
    gum style --foreground 9 "  ✗ ~/.local-secrets not found"
    gum style --foreground 8 "  Copy from: $DOTFILES_DIR/.local-secrets.example"
    echo
    read -rsp "Press any key…" -n1
    exit 0
fi

perms=$(stat -L -c '%a' "$SECRETS_FILE" 2>/dev/null || stat -L -f '%Lp' "$SECRETS_FILE" 2>/dev/null)
if [[ "$perms" == "600" ]]; then
    gum style --foreground 10 "  ✓ Permissions: 600 (correct)"
else
    gum style --foreground 9 "  ✗ Permissions: $perms (should be 600)"
    if gum confirm "Fix permissions now?" 2>/dev/null; then
        chmod 600 "$SECRETS_FILE"
        gum style --foreground 10 "  ✓ Fixed."
    fi
fi

echo
gum style --foreground 8 "  Defined keys (values hidden):"
grep -E '^[A-Z_]+=.' "$SECRETS_FILE" 2>/dev/null | \
    sed 's/=.*/=***/' | \
    while read -r line; do
        gum style --foreground 8 "    $line"
    done

echo
read -rsp "Press any key…" -n1

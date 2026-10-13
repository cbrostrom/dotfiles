#!/usr/bin/env bash
# Ensure the official managed Pi install (pi.dev) exists; keep ~/bin/pi on the dotfiles shim.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=pi-lib.sh
. "$ROOT/scripts/pi-lib.sh"

PI_SHIM="$HOME/.local/bin/pi"
MARKER="$HOME/.pi/agent/install/managed-install.json"

if [[ -f "$MARKER" && -x "$HOME/.pi/agent/bin/pi" ]]; then
    printf 'pi-managed: already installed (%s)\n' "$(cat "$HOME/.pi/agent/install/current-version" 2>/dev/null || echo '?')"
    "$HOME/.pi/agent/bin/pi" update self || true
else
    printf 'pi-managed: running https://pi.dev/install.sh\n'
    curl -fsSL https://pi.dev/install.sh | sh
fi

mkdir -p "$HOME/bin"
if [[ -x "$PI_SHIM" ]]; then
    ln -sf "$PI_SHIM" "$HOME/bin/pi"
    printf 'pi-managed: ~/bin/pi → %s (Pi-Bolt / PI_BACKEND shim)\n' "$PI_SHIM"
fi

printf 'pi-managed: run %s/scripts/pi-doctor.sh to verify\n' "$ROOT"

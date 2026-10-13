#!/usr/bin/env bash
# Re-sync Paseo plugins after fleet-update (force refresh). Sourced by host hooks.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
# shellcheck source=../../lib/paseo-fleet-env.sh
. "$ROOT/setup/lib/paseo-fleet-env.sh"

export PASEO_FORCE_PLUGIN_SYNC=1

if ! command -v paseo >/dev/null 2>&1; then
    printf '[paseo-fleet] paseo CLI missing; run install.sh for this profile\n' >&2
    exit 1
fi

if ! paseo plugin ls --json >/dev/null 2>&1; then
    paseo daemon start >/dev/null 2>&1 || true
fi

"$ROOT/setup/paseo.sh"

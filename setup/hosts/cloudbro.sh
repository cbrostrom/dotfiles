#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
printf '[fleet:%s] Paseo plugin sync (cloudbro)\n' "${DOTFILES_FLEET_HOST:-cloudbro}"
bash "$ROOT/setup/hosts/lib/paseo-fleet-sync.sh"

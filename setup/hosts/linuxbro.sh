#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
printf '[fleet:%s] Paseo plugin sync (linuxbro — keep agent concurrency low; ~6 GB RAM headroom)\n' \
    "${DOTFILES_FLEET_HOST:-linuxbro}"
bash "$ROOT/setup/hosts/lib/paseo-fleet-sync.sh"

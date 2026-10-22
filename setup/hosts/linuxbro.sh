#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
host="${DOTFILES_FLEET_HOST:-linuxbro}"
printf '[fleet:%s] T3 Code server\n' "$host"
DOTFILES_FLEET_HOST="$host" bash "$ROOT/setup/t3-server.sh"

#!/usr/bin/env bash
set -euo pipefail

ROOT="${DOTFILES_DIR:-$HOME/dotfiles}"
bash "$ROOT/scripts/install/pi-bolt.sh"

#!/usr/bin/env bash
# Compatibility entrypoint. New installs should use ./install.sh.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$ROOT/install.sh" "$@"

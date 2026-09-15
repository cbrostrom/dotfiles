#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
profile="${1:-}"

if [[ -z "$profile" ]]; then
    case "$(uname -s)" in
        Darwin) profile="macos" ;;
        Linux)
            if grep -qi microsoft /proc/version 2>/dev/null; then
                profile="wsl"
            else
                profile="linux"
            fi
            ;;
        *)
            printf 'error: pass an explicit profile\n' >&2
            exit 2
            ;;
    esac
fi

"$ROOT/stow.sh" apply "$profile"

case "$profile" in
    macos)
        "$ROOT/scripts/install/npm-globals.sh"
        "$ROOT/setup/pi.sh"
        "$ROOT/setup/cursor.sh"
        "$ROOT/setup/zed.sh"
        ;;
    linux | wsl)
        "$ROOT/scripts/install/npm-globals.sh"
        "$ROOT/setup/pi.sh"
        "$ROOT/setup/zed.sh"
        [[ "$profile" == "wsl" ]] && "$ROOT/setup/cursor.sh"
        ;;
    cloudbro)
        "$ROOT/scripts/install/npm-globals.sh"
        "$ROOT/setup/pi.sh"
        "$ROOT/setup/paseo.sh"
        ;;
    server) ;;
    *)
        printf 'error: unknown profile: %s\n' "$profile" >&2
        exit 2
        ;;
esac

printf 'dotfiles installed with profile: %s\n' "$profile"

#!/usr/bin/env bash
# Install or update Pi-Bolt (non-interactive). Safe to run from fleet host hooks.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

PIBOLT_INSTALL="${PIBOLT_INSTALL:-$HOME/.pi-bolt}"
PIBOLT_BIN_DIR="${PIBOLT_BIN_DIR:-$HOME/.local/bin}"
PIBOLT_YES="${PIBOLT_YES:-1}"
PIBOLT_EXTENSIONS="${PIBOLT_EXTENSIONS:-no}"
PIBOLT_SOURCE="${PIBOLT_SOURCE:-auto}"

if [[ -z "${PIBOLT_VARIANT:-}" ]]; then
    case "$(uname -s)-$(uname -m)" in
        Darwin-arm64) PIBOLT_VARIANT=arm64 ;;
        Darwin-*) echo "pi-bolt: unsupported macOS CPU ($(uname -m))" >&2; exit 1 ;;
        Linux-x86_64)
            if grep -qw avx2 /proc/cpuinfo 2>/dev/null; then
                PIBOLT_VARIANT=x64
            else
                PIBOLT_VARIANT=x64-baseline
            fi
            ;;
        Linux-*) echo "pi-bolt: Linux ARM64 builds are not published yet" >&2; exit 1 ;;
        *) echo "pi-bolt: unsupported OS: $(uname -s)" >&2; exit 1 ;;
    esac
fi

export PIBOLT_INSTALL PIBOLT_BIN_DIR PIBOLT_YES PIBOLT_EXTENSIONS PIBOLT_VARIANT PIBOLT_SOURCE

printf 'pi-bolt: installing variant %s (extensions=%s)\n' "$PIBOLT_VARIANT" "$PIBOLT_EXTENSIONS"
curl -fsSL https://pi-bolt.opensec.in/install.sh | sh

if command -v pi-bolt >/dev/null 2>&1; then
    pi-bolt --version
else
    echo "pi-bolt: install finished but pi-bolt is not on PATH ($PIBOLT_BIN_DIR)" >&2
    exit 1
fi

# shellcheck source=/dev/null
. "$ROOT/scripts/pi-lib.sh"
if [[ "$(pi_backend)" == bolt ]]; then
    printf 'pi-bolt: default `pi` resolves to Pi-Bolt (%s)\n' "$(pi_bolt_launcher)"
    printf 'pi-bolt: npm fallback: pi-npm (run pi-doctor.sh --fix to refresh)\n'
fi

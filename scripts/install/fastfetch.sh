#!/usr/bin/env bash
# Distro-aware fastfetch install/update.
#
#   fastfetch.sh              install (upgrade if installed)
#   fastfetch.sh --check      report only: installed vs latest, no changes
#
# Strategy by distro:
#   - Debian/Ubuntu with fastfetch in apt (trixie+, ubuntu 24.04+): apt install
#   - Older Debian (bookworm, glibc < 2.38): upstream .deb from GitHub releases
#     (never auto-updated; keep running --check/--update manually)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
MODE="install"
[[ "${1:-}" == "--check" ]] && MODE="check"

have() { command -v "$1" >/dev/null 2>&1; }

# --- detect distro -----------------------------------------------------------
if have apt-cache && [ -f /etc/os-release ]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    distro="${ID:-unknown}"
fi

# --- paths -------------------------------------------------------------------
installed_ver() {
    dpkg-query -W -f='${Version}\n' fastfetch 2>/dev/null | cut -d- -f1 | sed 's/^v//'
}

latest_ver() {
    curl -fsSL https://api.github.com/repos/fastfetch-cli/fastfetch/releases/latest \
        | grep -oP '"tag_name": "\K[^"]+' | tr -d v
}

glibc_major() {
    ldd --version 2>/dev/null | head -1 | grep -oP 'GLIBC\s*\K[0-9]+' || echo 0
}

arch_case() {
    case "$(uname -m)" in
        x86_64) echo "amd64" ;;
        aarch64) echo "arm64" ;;
        *) echo "unsupported: $(uname -m)" >&2; exit 1 ;;
    esac
}

apt_has_fastfetch() {
    apt-cache policy fastfetch 2>/dev/null | grep -q Candidate:
}

# --- actions -----------------------------------------------------------------
install_via_apt() {
    sudo apt-get update -qq
    sudo apt-get install -y fastfetch
}

install_via_deb() {
    local ver deb
    ver="$(latest_ver)"
    deb="fastfetch-linux-$(arch_case).deb"
    echo "fastfetch: latest upstream ${ver}, installing ${deb}"
    wget -q "https://github.com/fastfetch-cli/fastfetch/releases/download/v${ver}/${deb}" \
        -O /tmp/fastfetch.deb
    sudo dpkg -i /tmp/fastfetch.deb || sudo apt-get install -f -y
    rm -f /tmp/fastfetch.deb
}

# --- run ----------------------------------------------------------------------
case "$MODE" in
    check)
        cur="$(installed_ver)" ; latest="$(latest_ver)"
        if [[ "$cur" == "$latest" ]]; then
            echo "fastfetch: up to date (${cur})"
        else
            echo "fastfetch: installed ${cur:-none}, latest ${latest}"
            echo "  run: $(basename "$0")"
        fi
        ;;
    install)
        if apt_has_fastfetch; then
            echo "fastfetch: available in apt, installing via apt"
            install_via_apt
        else
            echo "fastfetch: not in ${distro} ${VERSION_ID} repos; using upstream .deb"
            install_via_deb
        fi
        ;;
esac

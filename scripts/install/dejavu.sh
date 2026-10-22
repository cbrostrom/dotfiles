#!/usr/bin/env bash
# =============================================================================
# scripts/install/dejavu.sh — install the deja-vu session-recall CLI from releases
# =============================================================================
# dejavu (https://github.com/vshulcz/deja-vu) — search past coding-agent
# sessions; provides the `dejavu mcp` server used by pi.
# NOTE: binary name is `dejavu`, not `deja` — the `deja` name belongs to
# Giammarco-Ferranti/deja (zsh ghost-text autosuggestions, brew).
#
# Idempotent: skips when the requested version is already installed;
# set DEJA_VERSION=latest (default) or a tag like v0.20.1 to pin.
# =============================================================================

set -euo pipefail

BIN_DIR="$HOME/.local/bin"
TARGET="$BIN_DIR/dejavu"
VERSION="${DEJA_VERSION:-latest}"

log() { printf '[dejavu-install] %s\n' "$*"; }
err() { printf '[dejavu-install] error: %s\n' "$*" >&2; }

case "$(uname -s)-$(uname -m)" in
    Linux-x86_64) plat="linux_amd64" ;;
    Linux-aarch64) plat="linux_arm64" ;;
    Darwin-arm64) plat="darwin_arm64" ;;
    Darwin-x86_64) plat="darwin_amd64" ;;
    *)
        err "unsupported platform: $(uname -s)-$(uname -m)"
        exit 1
        ;;
esac

if [[ "$VERSION" == "latest" ]]; then
    VERSION="$(curl -fsSLI -o /dev/null -w '%{url_effective}' \
        https://github.com/vshulcz/deja-vu/releases/latest)" || VERSION=""
    VERSION="${VERSION##*/tag/}"
    [[ "$VERSION" == http* ]] && VERSION=""
    # Tag from the releases/latest redirect (no API rate limit); keep an
    # installed binary if resolution still fails.
    if [[ -z "$VERSION" ]]; then
        if [[ -x "$TARGET" ]]; then
            log "could not resolve latest deja-vu release; keeping installed $TARGET"
            exit 0
        fi
        err "could not resolve latest deja-vu release"
        exit 1
    fi
fi

# Tags are vX.Y.Z, assets are dejavu_X.Y.Z_<plat>.tar.gz (no leading v).
asset_version="${VERSION#v}"

if [[ -x "$TARGET" ]] && "$TARGET" --version 2>/dev/null | grep -q "$asset_version"; then
    log "deja-vu $asset_version already installed"
    exit 0
fi

url="https://github.com/vshulcz/deja-vu/releases/download/$VERSION/deja-vu_${asset_version}_${plat}.tar.gz"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

log "downloading $url"
curl -fsSL "$url" -o "$tmp/deja.tar.gz"

tar -xzf "$tmp/deja.tar.gz" -C "$tmp"
binary="$(find "$tmp" -type f -name deja | head -1)"
[[ -n "$binary" ]] || { err "deja-vu binary not found in tarball"; exit 1; }

mkdir -p "$BIN_DIR"
install -m 755 "$binary" "$TARGET"
log "installed: $TARGET ($("$TARGET" --version 2>/dev/null || echo '?'))"

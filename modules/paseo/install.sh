#!/usr/bin/env bash
# =============================================================================
# modules/paseo/install.sh — sync patched Paseo plugins and install locally
# =============================================================================
# Opt-in: add "paseo" to ~/.config/dotfiles/modules.conf
# Update:  ./bootstrap.sh --only=paseo  or  paseo plugin update <id>
# =============================================================================
set -euo pipefail

DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
. "$DOTFILES_DIR/modules/_lib/log.sh"

PASEO_CONFIG_SRC="$DOTFILES_DIR/.config/paseo"
PASEO_PLUGINS_DIR="$PASEO_CONFIG_SRC/plugins"
PATCH_SCRIPT="$PASEO_CONFIG_SRC/patches/apply-v0.8.py"
MANIFEST="$PASEO_CONFIG_SRC/plugins.json"

if ! command -v paseo >/dev/null 2>&1; then
    warn "paseo CLI not found — skipping plugin install"
    exit 0
fi

if [[ ! -f "$MANIFEST" ]]; then
    err "missing manifest: $MANIFEST"
    exit 1
fi

mkdir -p "$PASEO_PLUGINS_DIR"

_sync_plugin() {
    local id="$1" repo="$2" subpath="${3:-}" ref="${4:-main}"
    local dest="$PASEO_PLUGINS_DIR/$id"
    local url="https://github.com/${repo}.git"
    local tmp
    tmp="$(mktemp -d)"

    log "sync $id from $repo${subpath:+:$subpath} @ $ref"
    git clone --depth 1 --branch "$ref" "$url" "$tmp/repo" >/dev/null 2>&1 \
        || git clone --depth 1 "$url" "$tmp/repo" >/dev/null

    rm -rf "$dest"
    if [[ -n "$subpath" ]]; then
        cp -R "$tmp/repo/$subpath" "$dest"
    else
        cp -R "$tmp/repo" "$dest"
        rm -rf "$dest/.git"
    fi
    rm -rf "$tmp"

    python3 "$PATCH_SCRIPT" "$dest"
}

while IFS= read -r row; do
    id="$(jq -r '.id' <<<"$row")"
    repo="$(jq -r '.repo' <<<"$row")"
    subpath="$(jq -r '.path // empty' <<<"$row")"
    ref="$(jq -r '.ref // "main"' <<<"$row")"
    _sync_plugin "$id" "$repo" "$subpath" "$ref"

    plugin_path="$PASEO_PLUGINS_DIR/$id"
    current_path="$(paseo plugin ls --json 2>/dev/null | jq -r --arg id "$id" '.[] | select(.id == $id) | .path // empty')"
    if [[ -n "$current_path" ]]; then
        if [[ "$current_path" == "$plugin_path" ]]; then
            log "reload $id"
            paseo plugin reload "$id" >/dev/null
        else
            log "repoint $id → dotfiles"
            paseo plugin remove "$id" >/dev/null
            paseo plugin install "$plugin_path" >/dev/null
        fi
    else
        log "install $id"
        paseo plugin install "$plugin_path" >/dev/null
    fi

    status="$(paseo plugin ls --json | jq -r --arg id "$id" '.[] | select(.id == $id) | .status')"
    if [[ "$status" == "running" ]]; then
        ok "$id → running"
    else
        err "$id → $status"
        paseo plugin ls --json | jq -r --arg id "$id" '.[] | select(.id == $id) | .error // empty'
        exit 1
    fi
done < <(jq -c '.plugins[]' "$MANIFEST")

ok "paseo plugins synced from dotfiles"

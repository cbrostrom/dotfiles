#!/usr/bin/env bash
# Synchronize tracked Paseo plugins without linking ~/.paseo runtime state.
set -euo pipefail

DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
. "$DOTFILES_DIR/setup/lib.sh"
activate_fnm

PASEO_CONFIG_SRC="$DOTFILES_DIR/sources/paseo"
PASEO_PLUGINS_DIR="$PASEO_CONFIG_SRC/plugins"
PATCH_SCRIPT="$PASEO_CONFIG_SRC/patches/apply-v0.8.py"
MANIFEST="$PASEO_CONFIG_SRC/plugins.json"
# Git-installed or superseded plugins — remove if still registered.
ORPHAN_PLUGINS=(
    attention-blocks-timeline
    usage-monitor
    agent-monitor
    reasoning-display
    subagent-activity
    usage-sidebar
)

if ! command -v paseo >/dev/null 2>&1; then
    die "paseo CLI not found; install it with: npm install -g @getpaseo/cli"
fi

if ! paseo plugin ls --json >/dev/null 2>&1; then
    relay_args=(--no-relay)
    if [[ "${PASEO_RELAY:-off}" == "on" ]]; then
        relay_args=(--relay)
    fi
    log "start local Paseo daemon (loopback, relay: ${PASEO_RELAY:-off})"
    paseo daemon start "${relay_args[@]}" >/dev/null
fi

# Fresh daemons start with plugins globally disabled, which makes every
# `paseo plugin reload/install` below fail with "Plugins are globally
# disabled". Enable them and reload before the sync loop.
PASEO_CONFIG="${PASEO_HOME:-$HOME/.paseo}/config.json"
mkdir -p "$(dirname "$PASEO_CONFIG")"
python3 - "$PASEO_CONFIG" <<'PYEOF'
import json, os, sys

config_path = sys.argv[1]
config = {}
if os.path.exists(config_path):
    with open(config_path) as f:
        config = json.load(f)

current = config.get("pluginsEnabled")
if current is not True:
    config["pluginsEnabled"] = True
    os.makedirs(os.path.dirname(config_path), exist_ok=True)
    with open(config_path, "w") as f:
        json.dump(config, f, indent=2)
        f.write("\n")
PYEOF
paseo reload --json >/dev/null

if [[ ! -f "$MANIFEST" ]]; then
    err "missing manifest: $MANIFEST"
    exit 1
fi

mkdir -p "$PASEO_PLUGINS_DIR"

for orphan in "${ORPHAN_PLUGINS[@]}"; do
    if paseo plugin ls --json 2>/dev/null | jq -e --arg id "$orphan" '.[] | select(.id == $id)' >/dev/null; then
        log "remove orphan $orphan"
        paseo plugin remove "$orphan" >/dev/null
    fi
done

_sync_plugin() {
    local id="$1" repo="$2" subpath="${3:-}" ref="${4:-main}" patch="${5:-}"
    local dest="$PASEO_PLUGINS_DIR/$id"
    local url="https://github.com/${repo}.git"
    local tmp
    tmp="$(mktemp -d)"

    log "sync $id from $repo${subpath:+:$subpath} @ $ref"
    git clone --depth 1 --branch "$ref" "$url" "$tmp/repo" >/dev/null 2>&1 ||
        git clone --depth 1 "$url" "$tmp/repo" >/dev/null

    rm -rf "$dest"
    if [[ -n "$subpath" ]]; then
        cp -R "$tmp/repo/$subpath" "$dest"
    else
        cp -R "$tmp/repo" "$dest"
        rm -rf "$dest/.git"
    fi
    rm -rf "$tmp"

    if [[ "$patch" == "v0.8" ]]; then
        python3 "$PATCH_SCRIPT" "$dest"
    fi

    # Synced copies ship without node_modules; plugins whose server code imports
    # non-host npm deps (e.g. @modelcontextprotocol/sdk) need them installed
    # before the daemon's build step runs. Plugins with no runtime dependencies
    # (source-only: Paseo supplies everything) skip the step entirely.
    # devDependencies-only plugins that import @getpaseo/* types in server code
    # also need node_modules present, or the daemon's esbuild boundary plugin
    # fails to resolve the type-only imports at install time.
    if [[ -f "$dest/package-lock.json" ]] && jq -e '((.dependencies // {}) + (.devDependencies // {})) | length > 0' "$dest/package.json" >/dev/null; then
        log "npm ci $id"
        if ! (cd "$dest" && npm ci >/dev/null 2>&1); then
            warn "npm ci failed for $id — plugin may fail to build"
        fi
    fi
}

_install_plugin() {
    local id="$1"
    local plugin_path="$PASEO_PLUGINS_DIR/$id"

    if [[ ! -d "$plugin_path" ]]; then
        err "missing plugin directory: $plugin_path"
        exit 1
    fi

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
}

while IFS= read -r row; do
    id="$(jq -r '.id' <<<"$row")"
    is_local="$(jq -r 'if .local == true then "true" elif (.repo | length) > 0 then "false" else "true" end' <<<"$row")"

    if [[ "$is_local" == "true" ]]; then
        log "local $id"
        _install_plugin "$id"
        continue
    fi

    repo="$(jq -r '.repo' <<<"$row")"
    subpath="$(jq -r '.path // empty' <<<"$row")"
    ref="$(jq -r '.ref // "main"' <<<"$row")"
    patch="$(jq -r '.patch // empty' <<<"$row")"
    _sync_plugin "$id" "$repo" "$subpath" "$ref" "$patch"
    _install_plugin "$id"
done < <(jq -c '.plugins[]' "$MANIFEST")

# Local maintenance plugin is intentionally outside the shared plugin manifest.
# It monitors this machine's Pi installation and has no remote source to sync.
if [[ -d "$PASEO_PLUGINS_DIR/pi-maintenance" ]]; then
    _install_plugin "pi-maintenance"
fi

# Paseo agents use a curated Pi launcher; direct terminal Pi keeps full discovery.
PASEO_CONFIG="${PASEO_HOME:-$HOME/.paseo}/config.json"
PI_PASEO_LAUNCHER="$DOTFILES_DIR/scripts/pi-paseo"
python3 - "$PASEO_CONFIG" "$PI_PASEO_LAUNCHER" <<'PYEOF'
import json, os, sys

config_path, launcher = sys.argv[1], sys.argv[2]
config = {}
if os.path.exists(config_path):
    with open(config_path) as f:
        config = json.load(f)

providers = config.setdefault("agents", {}).setdefault("providers", {})
pi = providers.setdefault("pi", {})
pi["enabled"] = True
pi["command"] = [launcher]

# Relay policy is profile-driven: install.sh sets PASEO_RELAY=on for hosts
# paired with the Paseo app (e.g. cloudbro). Default 'keep' leaves the live
# value untouched so the daemon's own config patches are never reverted.
relay = os.environ.get("PASEO_RELAY", "keep")
if relay in ("on", "off"):
    daemon = config.setdefault("daemon", {})
    daemon.setdefault("relay", {})["enabled"] = (relay == "on")

os.makedirs(os.path.dirname(config_path), exist_ok=True)
with open(config_path, "w") as f:
    json.dump(config, f, indent=2)
    f.write("\n")
PYEOF
paseo reload --json >/dev/null
ok "Paseo Pi provider → lean launcher"

ok "paseo plugins synced from dotfiles"

# Regenerate the capability map (plugins + pi extensions + skills)
if python3 "$DOTFILES_DIR/scripts/gen-capabilities.py"; then
    ok "capability map regenerated → ~/.agents/capabilities.md"
else
    log "WARN: gen-capabilities.py failed — manifest may be stale"
fi

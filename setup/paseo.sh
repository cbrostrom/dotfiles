#!/usr/bin/env bash
# Synchronize tracked Paseo plugins without linking ~/.paseo runtime state.
set -euo pipefail

DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
. "$DOTFILES_DIR/setup/lib.sh"
activate_fnm

PASEO_CONFIG_SRC="$DOTFILES_DIR/sources/paseo"
# Plugins are runtime state, not dotfiles: keep them outside the git tree so
# plugin syncs never dirty the checkout the fleet updater guards.
PASEO_PLUGINS_DIR="${PASEO_PLUGINS_DIR:-$HOME/.paseo/plugins}"
MANIFEST="$PASEO_CONFIG_SRC/plugins.json"
PLUGIN_CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/paseo-plugin-sync"
PASEO_FORCE_PLUGIN_SYNC="${PASEO_FORCE_PLUGIN_SYNC:-0}"
UPDATED_COUNT=0
INSTALLED_COUNT=0
REMOVED_COUNT=0
SKIPPED_COUNT=0
# Git-installed or superseded plugins — remove if still registered.
ORPHAN_PLUGINS=(
    attention-blocks-timeline
    usage-monitor
    agent-monitor
    reasoning-display
    subagent-activity
    usage-sidebar
    # merged into workspace-activity, peers-and-calls, pi-admin and ops (29-09-2026)
    agents-history
    calls-board
    pi-peer-roster
    pi-maintenance
    model-policy
    skills
    mcporter-pill
    force-stop
    hostname-tag
    bash-slash
)

if ! command -v paseo >/dev/null 2>&1; then
    die "paseo CLI not found; install it with: npm install -g @getpaseo/cli"
fi

if ! paseo plugin ls --json >/dev/null 2>&1; then
    # Paseo 0.9 removed --relay/--no-relay daemon flags; relay is config-driven
    # (daemon.relay.enabled), patched further below when PASEO_RELAY is set.
    log "start local Paseo daemon (loopback, relay: ${PASEO_RELAY:-off})"
    paseo daemon start >/dev/null
fi

# Password-protected daemon (auth management 2026-09-23): local CLI ops need
# PASEO_PASSWORD; dotfiles provisioning must not fail on gated daemons. Sync
# continues below only when the CLI can respond about plugins.
if ! paseo plugin ls --json >/dev/null 2>&1; then
    log "paseo ops skipped: daemon is password-protected and no PASEO_PASSWORD was provided"
    log "plugin sync is skipped; ssh in and run manually:"
    log "  ssh <host> "
    log "  PASEO_PASSWORD=<pw> paseo plugin ls   # or run: paseo daemon set-password"
    exit 0
fi

# Fresh daemons start with plugins globally disabled, which makes every
# `paseo plugin reload/install` below fail with "Plugins are globally
# disabled". Enable them and reload before the sync loop.
PASEO_CONFIG="${PASEO_HOME:-$HOME/.paseo}/config.json"
mkdir -p "$(dirname "$PASEO_CONFIG")"
plugins_enabled_changed="$(python3 - "$PASEO_CONFIG" <<'PYEOF'
import json, os, sys

config_path = sys.argv[1]
config = {}
if os.path.exists(config_path):
    with open(config_path) as f:
        config = json.load(f)

if config.get("pluginsEnabled") is True:
    print("0")
else:
    config["pluginsEnabled"] = True
    os.makedirs(os.path.dirname(config_path), exist_ok=True)
    with open(config_path, "w") as f:
        json.dump(config, f, indent=2)
        f.write("\n")
    print("1")
PYEOF
)"
if [[ "$plugins_enabled_changed" == "1" ]]; then
    paseo reload --json >/dev/null
fi

if [[ ! -f "$MANIFEST" ]]; then
    err "missing manifest: $MANIFEST"
    exit 1
fi

mkdir -p "$PASEO_PLUGINS_DIR"

# Host settings follow a plugin id; carry hostname-tag's alias over to ops once.
PLUGIN_SETTINGS_DIR="${PASEO_HOME:-$HOME/.paseo}/plugin-settings"
if [[ -f "$PLUGIN_SETTINGS_DIR/hostname-tag/tag.json" && ! -f "$PLUGIN_SETTINGS_DIR/ops/tag.json" ]]; then
    mkdir -p "$PLUGIN_SETTINGS_DIR/ops"
    cp "$PLUGIN_SETTINGS_DIR/hostname-tag/tag.json" "$PLUGIN_SETTINGS_DIR/ops/tag.json"
    log "migrated hostname-tag settings → ops"
fi

PLUGIN_STATE_JSON="$(paseo plugin ls --json)"
mkdir -p "$PLUGIN_CACHE_DIR"
rm -f "$PLUGIN_CACHE_DIR"/*.revision

_refresh_plugin_state() {
    PLUGIN_STATE_JSON="$(paseo plugin ls --json)"
}

for orphan in "${ORPHAN_PLUGINS[@]}"; do
    if jq -e --arg id "$orphan" '.[] | select(.id == $id)' <<<"$PLUGIN_STATE_JSON" >/dev/null; then
        log "remove orphan $orphan"
        paseo plugin remove "$orphan" >/dev/null
        REMOVED_COUNT=$((REMOVED_COUNT + 1))
        _refresh_plugin_state
    fi
done

# npm-workspace repos (bybrostrom/paseo-plugins) cannot be copied per subdirectory:
# plugins depend on sibling workspace packages. Paseo's own git install checks out the
# whole repo and runs the plugin's `npm ci` from inside it.
_remote_revision() {
    local repo="$1" ref="$2" key cache remote revision
    key="${repo//\//-}-${ref//\//-}"
    cache="$PLUGIN_CACHE_DIR/$key.revision"
    if [[ -s "$cache" ]]; then
        cat "$cache"
        return
    fi
    remote="https://github.com/${repo}.git"
    revision="$(git ls-remote "$remote" "refs/heads/$ref" 2>/dev/null | awk 'NR == 1 { print $1 }')"
    if [[ -z "$revision" ]]; then
        revision="$(git ls-remote "git@github.com:${repo}.git" "refs/heads/$ref" 2>/dev/null | awk 'NR == 1 { print $1 }')"
    fi
    if [[ -n "$revision" ]]; then
        printf '%s\n' "$revision" >"$cache"
    fi
    printf '%s\n' "$revision"
}

_plugin_path_unchanged() {
    local repo="$1" ref="$2" installed_revision="$3" remote_revision="$4" subpath="$5"
    local key mirror https ssh
    key="${repo//\//-}"
    mirror="$PLUGIN_CACHE_DIR/$key.git"
    https="https://github.com/${repo}.git"
    ssh="git@github.com:${repo}.git"

    if [[ ! -d "$mirror" ]]; then
        git clone --mirror "$https" "$mirror" >/dev/null 2>&1 ||
            git clone --mirror "$ssh" "$mirror" >/dev/null 2>&1 || return 1
    else
        git -C "$mirror" fetch --quiet --prune origin "$ref" || return 1
    fi
    git -C "$mirror" cat-file -e "$installed_revision^{commit}" 2>/dev/null ||
        git -C "$mirror" fetch --quiet origin "$installed_revision" || return 1
    git -C "$mirror" cat-file -e "$remote_revision^{commit}" 2>/dev/null || return 1
    git -C "$mirror" diff --quiet "$installed_revision" "$remote_revision" -- "$subpath"
}

_install_git_plugin() {
    local id="$1" repo="$2" subpath="$3" ref="$4"
    local remote="https://github.com/${repo}.git"
    local source installed_revision remote_revision status
    source="$(jq -r --arg id "$id" '.[] | select(.id == $id) | "\(.installation.identity.remote // "")|\(.installation.identity.pluginPath // "")"' <<<"$PLUGIN_STATE_JSON")"
    installed_revision="$(jq -r --arg id "$id" '.[] | select(.id == $id) | .installation.currentRevision // empty' <<<"$PLUGIN_STATE_JSON")"
    status="$(jq -r --arg id "$id" '.[] | select(.id == $id) | .status // empty' <<<"$PLUGIN_STATE_JSON")"
    remote_revision="$(_remote_revision "$repo" "$ref")"

    if [[ "$PASEO_FORCE_PLUGIN_SYNC" != "1" && "$source" == "$remote|$subpath" && "$status" == "running" ]]; then
        if [[ -n "$remote_revision" && "$installed_revision" == "$remote_revision" ]]; then
            ok "$id → current"
            SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
            return
        fi
        if [[ -n "$installed_revision" && -n "$remote_revision" ]] &&
            _plugin_path_unchanged "$repo" "$ref" "$installed_revision" "$remote_revision" "$subpath"; then
            ok "$id → unchanged at $installed_revision"
            SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
            return
        fi
    fi

    if [[ "$source" == "$remote|$subpath" ]]; then
        log "update $id @ $ref"
        paseo plugin update "$id" --ref "$ref" --yes >/dev/null
        UPDATED_COUNT=$((UPDATED_COUNT + 1))
    else
        [[ -n "$source" ]] && paseo plugin remove "$id" >/dev/null
        log "install $id from $repo:$subpath @ $ref"
        paseo plugin install "${remote}:${subpath}" --ref "$ref" >/dev/null
        INSTALLED_COUNT=$((INSTALLED_COUNT + 1))
    fi
    _refresh_plugin_state
}

_install_plugin() {
    local id="$1"
    # Preferred source for local plugins: the live dev repo (manifest `localPath`).
    # Falls back to the tracked copy under sources/ when the dev repo checkout is
    # missing (other machines), so a stale tracked copy never silently wins over
    # the repo where the work actually happens.
    local local_path plugin_path=""
    local_path="$(jq -r --arg id "$id" '.plugins[] | select(.id == $id) | .localPath // empty' "$MANIFEST")"
    if [[ -n "$local_path" ]]; then
        local_path="${local_path/#\~/$HOME}"
        if [[ -d "$local_path" ]]; then
            plugin_path="$local_path"
        else
            err "$id: localPath missing: $local_path"
        fi
    fi
    if [[ -z "$plugin_path" ]]; then
        plugin_path="$PASEO_PLUGINS_DIR/$id"
    fi

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
            log "repoint $id → $plugin_path"
            paseo plugin remove "$id" >/dev/null
            paseo plugin install "$plugin_path" >/dev/null
        fi
    else
        log "install $id"
        paseo plugin install "$plugin_path" >/dev/null
    fi
    _refresh_plugin_state
    _check_running "$id"
}

_check_running() {
    local id="$1" status
    status="$(jq -r --arg id "$id" '.[] | select(.id == $id) | .status // "missing"' <<<"$PLUGIN_STATE_JSON")"
    if [[ "$status" == "running" ]]; then
        ok "$id → running"
    else
        err "$id → $status"
        jq -r --arg id "$id" '.[] | select(.id == $id) | .error // empty' <<<"$PLUGIN_STATE_JSON"
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
    if [[ "$(jq -r '.install // empty' <<<"$row")" != "git" ]]; then
        die "$id: repository plugins must declare install=git"
    fi
    _install_git_plugin "$id" "$repo" "$subpath" "$ref"
    _check_running "$id"
done < <(jq -c '.plugins[]' "$MANIFEST")

# Paseo agents use a curated Pi launcher; direct terminal Pi keeps full discovery.
PASEO_CONFIG="${PASEO_HOME:-$HOME/.paseo}/config.json"
PI_PASEO_LAUNCHER="$DOTFILES_DIR/scripts/pi-paseo"
paseo_config_changed="$(python3 - "$PASEO_CONFIG" "$PI_PASEO_LAUNCHER" <<'PYEOF'
import json, os, sys

config_path, launcher = sys.argv[1], sys.argv[2]
config = {}
if os.path.exists(config_path):
    with open(config_path) as f:
        config = json.load(f)
before = json.dumps(config, sort_keys=True)

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

if json.dumps(config, sort_keys=True) == before:
    print("0")
else:
    os.makedirs(os.path.dirname(config_path), exist_ok=True)
    with open(config_path, "w") as f:
        json.dump(config, f, indent=2)
        f.write("\n")
    print("1")
PYEOF
)"
if [[ "$paseo_config_changed" == "1" ]]; then
    paseo reload --json >/dev/null
    ok "Paseo Pi provider → lean launcher"
fi

ok "paseo plugins: $SKIPPED_COUNT current, $UPDATED_COUNT updated, $INSTALLED_COUNT installed, $REMOVED_COUNT removed"

# Regenerate the capability map (plugins + pi extensions + skills)
if python3 "$DOTFILES_DIR/scripts/gen-capabilities.py"; then
    ok "capability map regenerated → ~/.agents/capabilities.md"
else
    log "WARN: gen-capabilities.py failed — manifest may be stale"
fi

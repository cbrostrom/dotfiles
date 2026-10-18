#!/usr/bin/env bash
# Synchronize Herdr config + plugins for this host's dotfiles profile.
#
#   ./setup/herdr.sh [profile]     profile or auto-detected (macos|linux|wsl|server|cloudbro)
#   HERDR_FORCE_SYNC=1            ignore cache markers and reinstall drift
#
# Design (mirrors setup/paseo.sh):
#   - Tracked inputs live under sources/herdr/ (config.base.toml, plugins.json).
#   - ~ config/runtime state stays out of git; this script manages it explicitly.
#   - config.toml is seeded only when missing; plugin-managed blocks (Radar) are
#     owned by their plugins and re-applied after plugin sync on attached hosts.

set -euo pipefail

DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
. "$DOTFILES_DIR/setup/lib.sh"

HERDR_SOURCE_DIR="$DOTFILES_DIR/sources/herdr"
HERDR_MANIFEST="$HERDR_SOURCE_DIR/plugins.json"
HERDR_BASE_CONFIG="$HERDR_SOURCE_DIR/config.base.toml"
HERDR_CONFIG_DIR="${HERDR_CONFIG_DIR:-$HOME/.config/herdr}"
HERDR_LIVE_CONFIG="$HERDR_CONFIG_DIR/config.toml"
HERDR_FORCE_SYNC="${HERDR_FORCE_SYNC:-0}"

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
            die "herdr: pass an explicit profile (macos|linux|wsl|server|cloudbro)"
            ;;
    esac
fi

case "$profile" in
    macos | linux | wsl) role="attached" ;;
    server | cloudbro) role="headless" ;;
    *) die "herdr: unknown profile: $profile" ;;
esac

ORPHANS="$(jq -r '.orphans[]?' "$HERDR_MANIFEST" 2>/dev/null || true)"

# ---------------------------------------------------------------------------
# 1. Herdr binary
# ---------------------------------------------------------------------------
if ! command -v herdr >/dev/null 2>&1; then
    case "$(uname -s)" in
        Darwin)
            if command -v brew >/dev/null 2>&1 && brew list --formula 2>/dev/null | grep -q '^herdr$'; then
                ok "herdr installed via brew"
            else
                log "installing herdr (official installer)"
                curl -fsSL https://herdr.dev/install.sh | sh
            fi
            ;;
        Linux)
            log "installing herdr (official installer)"
            curl -fsSL https://herdr.dev/install.sh | sh
            ;;
    esac
fi
command -v herdr >/dev/null 2>&1 || die "herdr not on PATH after install"
HERDR_VERSION="$(herdr --version 2>/dev/null || echo unknown)"
ok "herdr $HERDR_VERSION"

# ---------------------------------------------------------------------------
# 2. Base config (seed-only; live config is player piano territory afterwards)
# ---------------------------------------------------------------------------
if [[ ! -f "$HERDR_LIVE_CONFIG" ]]; then
    mkdir -p "$HERDR_CONFIG_DIR"
    cp "$HERDR_BASE_CONFIG" "$HERDR_LIVE_CONFIG"
    ok "seeded $HERDR_LIVE_CONFIG from config.base.toml"
else
    if ! herdr config check >/dev/null 2>&1; then
        warn "herdr config check failed; leaving live config untouched (inspect manually)"
        herdr config check 2>&1 | head -5 >&2 || true
    fi
fi

# ---------------------------------------------------------------------------
# 3. Plugin sync
# ---------------------------------------------------------------------------
command -v jq >/dev/null 2>&1 || die "jq is required (debian.sh/brew handle this)"

# herdr plugin list --json is wrapped: {"id":"cli:plugin","result":{"plugins":[…]}}.
# Validate: a transient server error can yield non-JSON output; fall back to an
# empty list so a herdr hiccup never aborts the whole sync.
refresh_list() {
    PLUGIN_LIST_JSON="$(herdr plugin list --json 2>/dev/null || true)"
    if ! jq -e . <<<"$PLUGIN_LIST_JSON" >/dev/null 2>&1; then
        PLUGIN_LIST_JSON='{"result":{"plugins":[]}}'
    fi
}
refresh_list

_install_plugin() {
    local repo="$1" ref="$2"
    if [[ "$ref" == "latest" ]]; then
        log "install $repo (unpinned; vet the manifest, then pin the revision in plugins.json)"
        herdr plugin install "$repo" --yes >/dev/null
    else
        log "install $repo @ $ref"
        herdr plugin install "$repo" --ref "$ref" --yes >/dev/null
    fi
}

_running_revision() {
    # `herdr plugin list` prints `- <id> (<name>) enabled [github:<owner>/<repo>[/subdir]@<rev>]`
    # The server may be unreachable (exit 5); return empty instead of failing.
    local owner="$1" name="$2"
    herdr plugin list 2>/dev/null | grep -F "github:$owner/$name" | head -1 |
        sed -E 's/.*@([0-9a-fA-F]{7,40})\].*/\1/' || true
}

_sync_plugin() {
    local repo="$1" ref="$2"
    local owner name installed_id running_rev
    owner="${repo%%/*}"
    name="${repo#*/}"
    # Iterate only the plugins array: a plain `.[]?` fallback would walk the
    # whole envelope object and error on its string values when the list is empty.
    installed_id="$(jq -r --arg owner "$owner" --arg name "$name" \
        '(.result.plugins // [])[] | select((.source.owner? // "") == $owner and (.source.repo? // "") == $name) | .plugin_id' \
        <<<"$PLUGIN_LIST_JSON" 2>/dev/null | head -1 || true)"
    # Fallback: match on the plain list (ids differ per plugin manifest).
    # The herdr server may be unreachable (exit 5); that is a normal state, so
    # treat an empty result as "not installed" and fall through to install.
    if [[ -z "$installed_id" ]]; then
        installed_id="$(herdr plugin list 2>/dev/null | grep -F "github:$owner/$name@" | head -1 | awk '{print $2}' | tr -d '()' || true)"
    fi

    if [[ -z "$installed_id" ]]; then
        _install_plugin "$repo" "$ref"
        refresh_list
        return
    fi

    running_rev="$(_running_revision "$owner" "$name")"
    if [[ "$ref" == "latest" ]]; then
        ok "herdr plugin $installed_id present (unpinned)"
        return
    fi
    if [[ -z "$running_rev" ]]; then
        ok "herdr plugin $installed_id present (revision not advertised)"
        return
    fi
    if [[ "$running_rev" == "$(printf '%s' "$ref" | cut -c1-${#running_rev})" ]]; then
        ok "herdr plugin $installed_id @ ${running_rev:0:8} current"
        return
    fi
    log "reinstall $installed_id @ $ref (drift: $running_rev)"
    herdr plugin uninstall "$installed_id" >/dev/null
    _install_plugin "$repo" "$ref"
    refresh_list
}

_sync_orphan() {
    local orphan_id="$1"
    if jq -e --arg id "$orphan_id" '.result.plugins[]? | select(.plugin_id == $id)' \
        <<<"$PLUGIN_LIST_JSON" >/dev/null 2>&1; then
        log "remove orphan $orphan_id"
        herdr plugin uninstall "$orphan_id" >/dev/null || true
        refresh_list
    fi
}

while IFS=$'\t' read -r repo ref roles; do
    [[ -z "$repo" ]] && continue
    has_role() {
        for candidate in $roles; do
            [[ "$candidate" == "$role" ]] && return 0
        done
        return 1
    }
    if ! has_role "$role"; then
        continue
    fi
    # radar is a TUI sidebar plugin: headless hosts never load it
    if [[ "$role" == "headless" && "$repo" == "hhdebb/herdr-radar" ]]; then
        continue
    fi
    _sync_plugin "$repo" "$ref"
done < <(jq -r '.plugins[] | [.repo, (.ref // "latest"), (.roles | join(" "))] | @tsv' "$HERDR_MANIFEST")

for orphan_id in $ORPHANS; do
    _sync_orphan "$orphan_id"
done

# Keep Radar's managed blocks repaired on attached hosts (idempotent install path).
radar_root="$(command ls -d "$HERDR_CONFIG_DIR"/plugins/github/hhdebb.herdr-radar-* 2>/dev/null | head -1 || true)"
if [[ -n "$radar_root" && -f "$radar_root/bin/configure.js" ]]; then
    if command -v node >/dev/null 2>&1; then
        if (cd "$radar_root" && node bin/configure.js --apply >/dev/null); then
            ok "radar managed blocks applied"
            herdr server reload-config >/dev/null 2>&1 || true
        else
            warn "radar configure --apply failed (is the server running?)"
        fi
    else
        warn "node missing; skipping radar managed-block repair"
    fi
fi

ok "herdr plugins synced for profile=$profile role=$role"
# The herdr server may legitimately not be running yet; a plugin list
# failure must not fail the whole install.
herdr plugin list 2>/dev/null || true

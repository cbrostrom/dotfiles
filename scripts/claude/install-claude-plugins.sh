#!/usr/bin/env bash
# Require bash 4+ (mapfile). macOS ships 3.2.
if (( BASH_VERSINFO[0] < 4 )); then
    for _candidate in /opt/homebrew/bin/bash /usr/local/bin/bash /home/linuxbrew/.linuxbrew/bin/bash; do
        if [[ -x "$_candidate" ]]; then
            exec "$_candidate" "$0" "$@"
        fi
    done
    echo "Error: bash 4+ required, found $BASH_VERSION. Install: brew install bash" >&2
    exit 1
fi

# Install Claude Code plugins declared in settings.local.json.
#
# Reads `extraKnownMarketplaces` + `enabledPlugins` and idempotently runs
# `claude plugin marketplace add` and `claude plugin install` for each.
#
# Safe to re-run — already-added marketplaces and already-installed plugins
# are skipped via the `claude plugin list` / `marketplace list` output.

set -euo pipefail

BLUE='\033[0;34m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
log_info()    { echo -e "${BLUE}[claude-plugins]${NC} $1"; }
log_success() { echo -e "${GREEN}[claude-plugins]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[claude-plugins]${NC} $1"; }
log_error()   { echo -e "${RED}[claude-plugins]${NC} $1" >&2; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SETTINGS="$SCRIPT_DIR/.claude/settings.local.json"

if ! command -v claude >/dev/null 2>&1; then
    log_warning "claude CLI not on PATH — skipping plugin install"
    exit 0
fi
if [[ ! -f "$SETTINGS" ]]; then
    log_warning "settings.local.json not found — run install-claude-config.sh first"
    exit 0
fi

# Marketplaces: name + github repo (only github source supported here).
mapfile -t MARKETPLACES < <(python3 - "$SETTINGS" <<'PYEOF'
import json, sys
d = json.load(open(sys.argv[1]))
for name, cfg in (d.get("extraKnownMarketplaces") or {}).items():
    src = (cfg or {}).get("source") or {}
    if src.get("source") == "github" and src.get("repo"):
        print(f"{name}\t{src['repo']}")
PYEOF
)

# Currently-known marketplaces (output of `claude plugin marketplace list`).
known_marketplaces() {
    # Lines look like: "  ❯ name"
    claude plugin marketplace list 2>/dev/null | awk '/^[[:space:]]*❯[[:space:]]/ {print $2}' || true
}

KNOWN="$(known_marketplaces)"
for entry in "${MARKETPLACES[@]}"; do
    name="${entry%%	*}"
    repo="${entry##*	}"
    if grep -qx "$name" <<< "$KNOWN"; then
        log_info "marketplace already added: $name"
    else
        log_info "adding marketplace: $name ($repo)"
        if claude plugin marketplace add "$repo" 2>&1 | sed "s/^/    /"; then
            log_success "added: $name"
        else
            log_warning "marketplace add failed: $name"
        fi
    fi
done

# Enabled plugins: only those set to true.
mapfile -t PLUGINS < <(python3 - "$SETTINGS" <<'PYEOF'
import json, sys
d = json.load(open(sys.argv[1]))
for spec, enabled in (d.get("enabledPlugins") or {}).items():
    if enabled:
        print(spec)
PYEOF
)

INSTALLED="$(claude plugin list 2>/dev/null || true)"
for spec in "${PLUGINS[@]}"; do
    plugin_name="${spec%@*}"
    if grep -q -E "(^|[[:space:]])${plugin_name}([[:space:]]|@|$)" <<< "$INSTALLED"; then
        log_info "plugin already installed: $spec"
        continue
    fi
    log_info "installing plugin: $spec"
    if claude plugin install "$spec" 2>&1 | sed "s/^/    /"; then
        log_success "installed: $spec"
    else
        log_warning "plugin install failed: $spec"
    fi
done

log_success "Claude plugins synced."

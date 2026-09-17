#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$ROOT/setup/lib.sh"

PI_HOME="${PI_HOME:-$HOME/.pi/agent}"
mkdir -p "$PI_HOME"

python3 "$ROOT/setup/pi/settings.py" \
    "$ROOT/setup/pi/settings.base.json" \
    "$PI_HOME/configs/model-policy.json" \
    "$PI_HOME/settings.json" \
    "$PI_HOME/host.json"

for patch in "$ROOT/setup/pi/patches/"*.sh; do
    [[ -f "$patch" ]] || continue
    bash "$patch"
done

# Stowed extension files are symlinks into ~/dotfiles; Pi loads the real path, so
# node_modules must live in the stow source tree (not only under ~/.pi/...).
# A .platform stamp records where node_modules was built; a mismatch (e.g.
# macOS-built modules reused on Linux) forces a reinstall.
activate_fnm
stamp="$(uname -s)-$(uname -m)"
while IFS= read -r -d '' pkg; do
    ext_dir="$(dirname "$pkg")"
    stamp_file="$ext_dir/node_modules/.platform"
    current_stamp="$(cat "$stamp_file" 2>/dev/null || echo missing)"
    if [[ ! -d "$ext_dir/node_modules" || "$current_stamp" != "$stamp" ]]; then
        if [[ -d "$ext_dir/node_modules" ]]; then
            info "stale node_modules ($current_stamp on $stamp): reinstalling Pi extension deps: ${ext_dir#$ROOT/}"
            rm -rf "$ext_dir/node_modules"
        else
            info "installing Pi extension deps: ${ext_dir#$ROOT/}"
        fi
        (cd "$ext_dir" && npm ci --ignore-scripts) \
            || warn "Pi extension npm ci failed: $ext_dir"
        echo "$stamp" >"$ext_dir/node_modules/.platform" 2>/dev/null \
            || warn "could not write platform stamp: $ext_dir/node_modules"
    fi
done < <(find "$ROOT/stow/pi/.pi/agent/extensions" -name package.json -not -path '*/node_modules/*' -print0 2>/dev/null)

PRUNED_NPM=(pi-tool-display)
for pkg in "${PRUNED_NPM[@]}"; do
    if [[ -d "$PI_HOME/npm/node_modules/$pkg" ]] && command -v pi >/dev/null 2>&1; then
        info "pruning removed Pi package: npm:$pkg"
        pi uninstall "npm:$pkg" >/dev/null 2>&1 || warn "could not uninstall npm:$pkg (run: pi uninstall npm:$pkg)"
    fi
    if [[ ! -d "$PI_HOME/npm/node_modules/$pkg" && -d "$PI_HOME/extensions/$pkg" ]]; then
        rm -rf "$PI_HOME/extensions/$pkg"
    fi
done

if ! python3 "$ROOT/scripts/gen-capabilities.py"; then
    warn "capability map generation failed"
fi

ok "Pi runtime settings configured"

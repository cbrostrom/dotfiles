#!/usr/bin/env bash
# =============================================================================
# modules/pi/install.sh — install PI coding-agent daily-driver config
# =============================================================================
# Opt-in per machine: add "pi" to ~/.config/dotfiles/modules.conf
#
# What this installs (symlinked from dotfiles, git-tracked):
#   ~/.pi/agent/AGENTS.md          ← global policy adapter
#   ~/.pi/agent/spark.json         ← Spark presets + recap config
#   ~/.pi/agent/hook/hooks.yaml    ← pi-yaml-hooks global hooks (gated)
#
# What this PATCHES (merged, not symlinked — PI writes runtime fields here):
#   ~/.pi/agent/settings.json      ← packages, model, trust defaults
#
# What this preserves (local-only, never touched):
#   ~/.pi/agent/auth.json
#   ~/.pi/agent/cursor-sdk-model-list.json
#   ~/.pi/agent/cursor-sdk.json
#   ~/.pi/agent/sessions/
#   ~/.pi/agent/npm/
#   ~/.pi/agent/pi-stats/
#   ~/.pi/agent/trust.json
# =============================================================================
set -euo pipefail
DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
. "$DOTFILES_DIR/modules/_lib/log.sh"

PI_SRC="$DOTFILES_DIR/.config/pi/agent"
PI_DST="$HOME/.pi/agent"

# ── 0) check PI is installed ──────────────────────────────────────────────────
if ! command -v pi >/dev/null 2>&1; then
    warn "pi not found in PATH — skipping PI config install"
    exit 0
fi

# ── 1) directories ────────────────────────────────────────────────────────────
mkdir -p "$PI_DST/hook"

# ── 2) helper: safe symlink with backup ──────────────────────────────────────
_symlink() {
    local src="$1" dst="$2" label="$3"
    if [[ -L "$dst" ]]; then
        # Already a symlink — update if target changed
        local current
        current="$(readlink "$dst")"
        if [[ "$current" == "$src" ]]; then
            ok "$label symlink already up to date"
        else
            ln -sf "$src" "$dst"
            ok "$label symlink updated ($current → $src)"
        fi
    elif [[ -e "$dst" ]]; then
        local backup="${dst}.bak.$(date +%Y%m%d_%H%M%S)"
        mv "$dst" "$backup"
        warn "$label: existing file backed up → $(basename "$backup")"
        ln -sf "$src" "$dst"
        ok "$label symlinked"
    else
        ln -sf "$src" "$dst"
        ok "$label symlinked"
    fi
}

# ── 3) symlink user-authored config files ────────────────────────────────────
_symlink "$PI_SRC/AGENTS.md"           "$PI_DST/AGENTS.md"           "AGENTS.md"
_symlink "$PI_SRC/spark.json"          "$PI_DST/spark.json"           "spark.json"

# ── 4) pi shim at ~/.local/bin/pi ────────────────────────────────────────────
# Keeps `pi` resolvable even when fnm switches to a project-local node version.
mkdir -p "$HOME/.local/bin"
_symlink "$DOTFILES_DIR/scripts/pi" "$HOME/.local/bin/pi" "~/.local/bin/pi shim"

# ── 4b) user extensions — symlink every .ts in extensions/ ──────────────────
EXT_SRC="$PI_SRC/extensions"
EXT_DST="$PI_DST/extensions"
if [[ -d "$EXT_SRC" ]]; then
    mkdir -p "$EXT_DST"
    for f in "$EXT_SRC"/*.ts; do
        [[ -e "$f" ]] || continue
        name="$(basename "$f")"
        _symlink "$f" "$EXT_DST/$name" "extensions/$name"
    done
fi

# ── 5) hooks.yaml — only if pi-yaml-hooks is installed or will be ─────────────
# We always symlink so the file is ready; pi-yaml-hooks picks it up automatically
# when installed. Run /hooks-validate inside PI to confirm compatibility.
_symlink "$PI_SRC/hook/hooks.yaml"     "$PI_DST/hook/hooks.yaml"      "hook/hooks.yaml"
log "hooks.yaml symlinked — install pi-yaml-hooks and run /hooks-validate to activate"

# ── 5b) prompt templates (/end and friends) ───────────────────────────────────
# pi-prompt-template-model loads from ~/.pi/agent/prompts/; symlink each .md
PROMPT_SRC="$PI_SRC/prompts"
PROMPT_DST="$PI_DST/prompts"
if [[ -d "$PROMPT_SRC" ]]; then
    mkdir -p "$PROMPT_DST"
    for f in "$PROMPT_SRC"/*.md; do
        [[ -e "$f" ]] || continue
        name="$(basename "$f")"
        _symlink "$f" "$PROMPT_DST/$name" "prompts/$name"
    done
fi

# ── 5) merge settings.base.json into settings.json ───────────────────────────
# PI manages runtime fields (lastChangelogVersion, etc.) in settings.json.
# We merge our desired config without overwriting runtime state.
python3 - "$PI_SRC/settings.base.json" "$PI_DST/settings.json" <<'PYEOF'
import json, os, sys

base_path = sys.argv[1]
local_path = sys.argv[2]

with open(base_path) as f:
    base = json.load(f)

local = {}
if os.path.exists(local_path):
    with open(local_path) as f:
        try:
            local = json.load(f)
        except json.JSONDecodeError:
            print("[warn] settings.json parse error — initialising from base")

# Fields PI manages at runtime — never overwrite with base values
RUNTIME_KEYS = {"lastChangelogVersion", "trackingId"}

result = dict(local)

# Apply non-runtime scalar and object fields from base
for k, v in base.items():
    if k in RUNTIME_KEYS:
        continue
    if k == "packages":
        continue  # handled below
    if isinstance(v, dict) and isinstance(result.get(k), dict):
        result[k] = {**result[k], **v}
    else:
        result[k] = v

# Packages: ensure all base packages are present, preserve extras
base_pkgs = base.get("packages", [])
local_pkgs = list(local.get("packages", []))
added = []
for pkg in base_pkgs:
    if pkg not in local_pkgs:
        local_pkgs.append(pkg)
        added.append(pkg)
result["packages"] = local_pkgs

# Write back
with open(local_path, "w") as f:
    json.dump(result, f, indent=2)
    f.write("\n")

if added:
    print(f"[pi] settings.json: added packages {added}")
else:
    print("[pi] settings.json: packages already up to date")
PYEOF

ok "settings.json patched"

# ── 6) summary ────────────────────────────────────────────────────────────────
log "PI install complete. Manual steps:"
log "  1. Open PI and run:  /preset          (to confirm Spark presets loaded)"
log "  2. Run:              /recap            (to test recap on Haiku 4.5)"
log "  3. Install hooks:    pi install npm:pi-yaml-hooks"
log "     Then validate:    /hooks-validate   /hooks-status"
log "  4. Trust your repos: /trust  (once, per project, inside PI)"
log "  5. Update PI:        fnm use default && pi update self"
log "     (always update from fnm default so the shim stays aligned)"

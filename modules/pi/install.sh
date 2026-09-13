#!/usr/bin/env bash
# =============================================================================
# modules/pi/install.sh — install PI coding-agent daily-driver config
# =============================================================================
# Opt-in per machine: add "pi" to ~/.config/dotfiles/modules.conf
#
# What this installs (symlinked from dotfiles, git-tracked):
#   ~/.pi/agent/AGENTS.md          <- global policy adapter
#   ~/.pi/agent/mcp.json           <- classic MCP (higgins/deja hot path)
#   ~/.pi/agent/mcporter.json      <- pi-mcporter exposure policy (index default)
#   ~/.pi/web-search.json          <- focused Exa/raw web-search config
#   ~/.pi/agent/hook/hooks.yaml    <- pi-yaml-hooks global hooks (gated)
#   ~/.pi/agent/pi-permissions.jsonc <- pi-permission-system policy (NOT a security boundary — no enforcing package)
#   ~/.pi/agent/configs/model-policy.json <- model allow/deny groups per host (source of truth)
#
# What this GENERATES (runtime-only, host-specific, not tracked):
#   ~/.pi/agent/host.json          <- resolved host slug (override: PI_HOST_SLUG=<slug>)
#   ~/.pi/agent/settings.json enabledModels/defaultProvider/defaultModel/defaultThinkingLevel
#                                    <- generated from model-policy.json + host.json each install run
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
_symlink "$PI_SRC/AGENTS.md" "$PI_DST/AGENTS.md" "AGENTS.md"
_symlink "$PI_SRC/mcp.json" "$PI_DST/mcp.json" "mcp.json"
_symlink "$PI_SRC/mcporter.json" "$PI_DST/mcporter.json" "mcporter.json"
# pi-permissions.jsonc: no enforcing package is installed. Pi has no built-in
# sandbox or permission popups — do not treat this file as a security
# boundary. Kept symlinked for forward compatibility only.
_symlink "$PI_SRC/pi-permissions.jsonc" "$PI_DST/pi-permissions.jsonc" "pi-permissions.jsonc"
_symlink "$PI_SRC/web-search.json" "$HOME/.pi/web-search.json" "web-search.json"
mkdir -p "$PI_DST/configs"
_symlink "$PI_SRC/configs/model-policy.json" "$PI_DST/configs/model-policy.json" "configs/model-policy.json"
_symlink "$PI_SRC/configs/protected-paths.json" "$PI_DST/configs/protected-paths.json" "configs/protected-paths.json"

# ── 4) pi shim at ~/.local/bin/pi ────────────────────────────────────────────
# Keeps `pi` resolvable even when fnm switches to a project-local node version.
mkdir -p "$HOME/.local/bin"
_symlink "$DOTFILES_DIR/scripts/pi" "$HOME/.local/bin/pi" "~/.local/bin/pi shim"

# ── 4b) tools — symlink tools/ directory ─────────────────────────────────────
TOOLS_SRC="$PI_SRC/tools"
TOOLS_DST="$PI_DST/tools"
if [[ -d "$TOOLS_SRC" ]]; then
    if [[ -L "$TOOLS_DST" ]]; then
        current="$(readlink "$TOOLS_DST")"
        if [[ "$current" == "$TOOLS_SRC" ]]; then
            ok "tools/ symlink already up to date"
        else
            ln -sfn "$TOOLS_SRC" "$TOOLS_DST"
            ok "tools/ symlink updated ($current → $TOOLS_SRC)"
        fi
    elif [[ -e "$TOOLS_DST" ]]; then
        warn "tools/ exists but not symlinked — skipping (move it manually)"
    else
        ln -sfn "$TOOLS_SRC" "$TOOLS_DST"
        ok "tools/ symlinked → quick job runner scripts available"
    fi
fi

# ── 4c) user extensions — symlink every .ts and every extension directory ────
EXT_SRC="$PI_SRC/extensions"
EXT_DST="$PI_DST/extensions"
if [[ -d "$EXT_SRC" ]]; then
    mkdir -p "$EXT_DST"
    for f in "$EXT_SRC"/*.ts; do
        [[ -e "$f" ]] || continue
        name="$(basename "$f")"
        _symlink "$f" "$EXT_DST/$name" "extensions/$name"
    done
    for d in "$EXT_SRC"/*/; do
        [[ -d "$d" ]] || continue
        name="$(basename "$d")"
        _symlink "$d" "$EXT_DST/$name" "extensions/$name"
    done
fi

# ── 5) hooks.yaml — only if pi-yaml-hooks is installed or will be ─────────────
# We always symlink so the file is ready; pi-yaml-hooks picks it up automatically
# when installed. Run /hooks-validate inside PI to confirm compatibility.
_symlink "$PI_SRC/hook/hooks.yaml" "$PI_DST/hook/hooks.yaml" "hook/hooks.yaml"
log "hooks.yaml symlinked — install pi-yaml-hooks and run /hooks-validate to activate"

# ── 5a) pi-tool-display config — write ownership off (avoid extension conflicts)
# pi-tool-display defaults all tool ownership to true; keep write=false so other
# packages that register write do not conflict after reinstalls.
TDD_CFG="$PI_DST/extensions/pi-tool-display/config.json"
if [[ -f "$TDD_CFG" ]]; then
    # Config exists — verify write ownership is disabled
    if python3 -c "
import json, sys
with open('$TDD_CFG') as f:
    cfg = json.load(f)
overrides = cfg.get('registerToolOverrides', {})
if overrides.get('write', True) is True:
    sys.exit(1)
" 2>/dev/null; then
        ok "pi-tool-display config: write ownership already disabled"
    else
        # Patch: set write to false
        python3 -c "
import json
with open('$TDD_CFG') as f:
    cfg = json.load(f)
cfg.setdefault('registerToolOverrides', {})['write'] = False
with open('$TDD_CFG', 'w') as f:
    json.dump(cfg, f, indent=2)
    f.write('\n')
print('[pi] pi-tool-display config: write ownership disabled')
"
    fi
else
    # No config — create it
    mkdir -p "$(dirname "$TDD_CFG")"
    cat >"$TDD_CFG" <<'JSON'
{
  "registerToolOverrides": {
    "read": true,
    "grep": true,
    "find": true,
    "ls": true,
    "bash": true,
    "edit": true,
    "write": false
  }
}
JSON
    ok "pi-tool-display config created (write ownership disabled)"
fi

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

# Fields PI manages at runtime — never overwrite with base values.
# enabledModels/defaultProvider/defaultModel/defaultThinkingLevel are owned by
# step 5c (model-policy.json → host policy) and must never be reset by this
# generic base merge.
RUNTIME_KEYS = {
    "lastChangelogVersion", "trackingId",
    "enabledModels", "defaultProvider", "defaultModel", "defaultThinkingLevel",
}

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

# ── 5c) resolve host policy → enabledModels + per-host defaults ──────────────
# Reads configs/model-policy.json (tracked, symlinked in step 3), resolves
# this machine's host slug, expands its model groups, validates each model
# against `pi --list-models`, and writes the result into settings.json.
# This runs AFTER the generic merge above so its output is never clobbered by
# base's (now vestigial) model defaults, and its own writes are re-applied on
# every install run so a stale runtime enabledModels list cannot survive a
# policy or catalog change. Fails closed: a model referenced in the policy
# that no longer appears in `pi --list-models` is dropped, not preserved.
POLICY_FILE="$PI_DST/configs/model-policy.json"
if [[ -f "$POLICY_FILE" ]]; then
    python3 - "$POLICY_FILE" "$PI_DST/host.json" "$PI_DST/settings.json" <<'PYEOF'
import json, os, socket, subprocess, sys
from datetime import datetime

policy_path, host_path, settings_path = sys.argv[1], sys.argv[2], sys.argv[3]

with open(policy_path) as f:
    policy = json.load(f)

hosts = policy["hosts"]

# ── resolve host slug ──────────────────────────────────────────────────────
env_slug = os.environ.get("PI_HOST_SLUG")
existing_slug = None
if os.path.exists(host_path):
    try:
        with open(host_path) as f:
            existing_slug = json.load(f).get("slug")
    except (json.JSONDecodeError, OSError):
        existing_slug = None

short_hostname = socket.gethostname().split(".")[0]

if env_slug and env_slug in hosts:
    slug = env_slug
elif existing_slug and existing_slug in hosts:
    slug = existing_slug
else:
    slug = next((s for s, hp in hosts.items() if short_hostname in hp.get("aliases", [])), None)
    if slug is None:
        slug = "default-desktop" if "default-desktop" in hosts else next(iter(hosts))

with open(host_path, "w") as f:
    json.dump(
        {"slug": slug, "hostname": short_hostname, "resolvedAt": datetime.now().isoformat(timespec="seconds")},
        f, indent=2,
    )
    f.write("\n")

hp = hosts[slug]

# ── expand host groups → enabledModels (dedup, ordered) ─────────────────────
groups = policy["groups"]
seen = set()
enabled = []
for group_name in hp["groups"]:
    for key in groups.get(group_name, []):
        if key not in seen:
            seen.add(key)
            enabled.append(key)

# ── validate against pi --list-models — fail closed on stale entries ────────
try:
    result = subprocess.run(["pi", "--list-models"], capture_output=True, text=True, timeout=15)
    catalog = set()
    for line in result.stdout.splitlines()[1:]:  # skip header row
        parts = line.split()
        if len(parts) >= 2:
            catalog.add(f"{parts[0]}/{parts[1]}")
    if catalog:
        missing = [k for k in enabled if k not in catalog]
        if missing:
            print(f"[pi] model-policy: dropping {len(missing)} model(s) not in pi --list-models: {missing}")
            enabled = [k for k in enabled if k not in missing]
    else:
        print("[pi] model-policy: pi --list-models returned no rows (not authenticated?) — skipping validation")
except (subprocess.TimeoutExpired, FileNotFoundError, OSError) as e:
    print(f"[pi] model-policy: could not run pi --list-models ({e}) — skipping validation")

# ── write into settings.json ─────────────────────────────────────────────────
settings = {}
if os.path.exists(settings_path):
    try:
        with open(settings_path) as f:
            settings = json.load(f)
    except json.JSONDecodeError:
        settings = {}

settings["enabledModels"] = enabled
settings["defaultProvider"] = hp.get("defaultProvider") or policy["defaults"]["fallbackModel"].split("/")[0]
settings["defaultModel"] = hp.get("defaultModel") or policy["defaults"]["fallbackModel"].split("/", 1)[1]
settings["defaultThinkingLevel"] = hp.get("defaultThinkingLevel") or policy["defaults"]["thinking"]

with open(settings_path, "w") as f:
    json.dump(settings, f, indent=2)
    f.write("\n")

print(f"[pi] model-policy: host={slug} enabledModels={len(enabled)} default={settings['defaultProvider']}/{settings['defaultModel']}")
PYEOF
    ok "settings.json: host policy applied (see host.json for resolved slug)"
else
    warn "configs/model-policy.json missing — enabledModels left untouched by policy"
fi


# ── 5d) pi-ask-user schema patch (accept options[].label alias) ───────────────
PATCH_SCRIPT="$PI_SRC/patches/apply-pi-ask-user-label-patch.sh"
if [[ -x "$PATCH_SCRIPT" ]]; then
    "$PATCH_SCRIPT"
elif [[ -f "$PATCH_SCRIPT" ]]; then
    bash "$PATCH_SCRIPT"
else
    warn "pi-ask-user patch script missing — skip"
fi

# ── 5e) pi-cursor-sdk strict MCP-only patch (context-mode enforcement) ────────
# Forces Cursor local agents to route every action through the MCP bridge so
# context-mode-enforcer (extensions/context-mode-enforcer) can see and gate it.
# Escape hatch: PI_CURSOR_STRICT_MCP_ONLY=0.
PATCH_SCRIPT="$PI_SRC/patches/apply-pi-cursor-sdk-strict-mcp-patch.sh"
if [[ -x "$PATCH_SCRIPT" ]]; then
    "$PATCH_SCRIPT"
elif [[ -f "$PATCH_SCRIPT" ]]; then
    bash "$PATCH_SCRIPT"
else
    warn "pi-cursor-sdk strict-mcp patch script missing — skip"
fi

# ── 5b) capability map ────────────────────────────────────────────────────
if python3 "$DOTFILES_DIR/scripts/gen-capabilities.py"; then
    ok "capability map regenerated → ~/.agents/capabilities.md"
else
    log "WARN: gen-capabilities.py failed — manifest may be stale"
fi

# ── 6) summary ────────────────────────────────────────────────────────────────
log "PI install complete. Manual steps:"
log "  1. Verify MCP:      /mcp status         (higgins, deja directTools)"
log "  2. MCPorter:         /mcporter status    (index exposure via pi-mcporter)"
log "  3. Cursor auth:     /login → API key → Cursor (or CURSOR_API_KEY)"
log "  4. Run:              /reload            (pick up extensions + prompts)"
log "  5. Scoped models:    /scoped-models     (Ctrl+P cycles enabledModels)"
log "  6. Run:              /hooks-validate    (to confirm hooks compatible)"
log "  7. Trust your repos: /trust             (once, per project, inside PI)"
log "  8. Update PI:        fnm use default && pi update self"
log "     (always update from fnm default so the shim stays aligned)"
log "  9. Cursor spend:     set on-demand limit to \$0 in Cursor dashboard"
log " 10. Host policy:      cat ~/.pi/agent/host.json  (wrong host? set PI_HOST_SLUG=<slug> and re-run install)"

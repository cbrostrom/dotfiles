#!/usr/bin/env bash
# Snapshot Claude config state for the current device.
# Writes .claude/devices/<hostname>.json — tracked in git so each machine
# can see what every other machine has installed.
#
# Subcommands:
#   write   — refresh this device's snapshot (default)
#   list    — print table across all snapshots
#   show <host> — dump a single device's snapshot

if (( BASH_VERSINFO[0] < 4 )); then
    for _candidate in /opt/homebrew/bin/bash /usr/local/bin/bash /home/linuxbrew/.linuxbrew/bin/bash; do
        if [[ -x "$_candidate" ]]; then
            exec "$_candidate" "$0" "$@"
        fi
    done
    echo "Error: bash 4+ required, found $BASH_VERSION." >&2
    exit 1
fi

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DEVICES_DIR="$SCRIPT_DIR/.claude/devices"
SETTINGS="$SCRIPT_DIR/.claude/settings.local.json"
MCP_LIST="$SCRIPT_DIR/.claude/mcp-servers.list"
SKILLS_LIST="$SCRIPT_DIR/.claude/skills/skills.list"

mkdir -p "$DEVICES_DIR"

cmd_write() {
    local host os arch profile snapshot
    host="$(hostname -s 2>/dev/null || hostname)"
    case "$(uname -s)" in
        Darwin) os="macos" ;;
        Linux)
            if grep -q Microsoft /proc/version 2>/dev/null; then
                os="wsl"
            else
                os="linux"
            fi
            ;;
        *) os="$(uname -s)" ;;
    esac
    arch="$(uname -m)"
    profile="${PROFILE:-}"
    if [[ -z "$profile" && -f "$SCRIPT_DIR/modules/_lib/platform.sh" ]]; then
        profile="$(bash -c '. "$1/modules/_lib/platform.sh" >/dev/null 2>&1; profile_tag' _ "$SCRIPT_DIR" 2>/dev/null || true)"
    fi
    profile="${profile:-unknown}"

    snapshot="$DEVICES_DIR/${host}.json"

    python3 - "$SETTINGS" "$MCP_LIST" "$SKILLS_LIST" "$snapshot" \
            "$host" "$os" "$arch" "$profile" <<'PYEOF'
import json, os, sys, datetime, re

settings_path, mcp_path, skills_path, out_path, host, osname, arch, profile = sys.argv[1:9]

settings = {}
if os.path.isfile(settings_path):
    with open(settings_path) as f:
        settings = json.load(f)

enabled_plugins = sorted(
    spec for spec, on in (settings.get("enabledPlugins") or {}).items() if on
)
disabled_plugins = sorted(
    spec for spec, on in (settings.get("enabledPlugins") or {}).items() if not on
)
marketplaces = sorted((settings.get("extraKnownMarketplaces") or {}).keys())
mcp_servers_settings = sorted((settings.get("mcpServers") or {}).keys())

mcp_servers_list = []
if os.path.isfile(mcp_path):
    with open(mcp_path) as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            name = line.split("|", 1)[0].strip()
            if name:
                mcp_servers_list.append(name)

skills = []
if os.path.isfile(skills_path):
    with open(skills_path) as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            skills.append(line)

out = {
    "host": host,
    "os": osname,
    "arch": arch,
    "profile": profile,
    "last_synced": datetime.datetime.utcnow().isoformat(timespec="seconds") + "Z",
    "marketplaces": marketplaces,
    "enabled_plugins": enabled_plugins,
    "disabled_plugins": disabled_plugins,
    "mcp_servers_settings": mcp_servers_settings,
    "mcp_servers_list": mcp_servers_list,
    "skills": skills,
}
with open(out_path, "w") as f:
    json.dump(out, f, indent=2, ensure_ascii=False)
print(f"[devices] wrote {out_path}")
PYEOF
}

cmd_list() {
    python3 - "$DEVICES_DIR" <<'PYEOF'
import json, os, sys, glob

devices_dir = sys.argv[1]
files = sorted(glob.glob(os.path.join(devices_dir, "*.json")))
if not files:
    print("(no device snapshots yet — run device-snapshot.sh write)")
    sys.exit(0)

devices = [json.load(open(f)) for f in files]

# Header
fmt = "{host:<22} {os:<8} {arch:<8} {profile:<16} {plugins:>3} {mcp:>3} {skills:>3}  {last}"
print(fmt.format(host="HOST", os="OS", arch="ARCH",
                 profile="PROFILE", plugins="PLG", mcp="MCP",
                 skills="SKL", last="LAST SYNC"))
print("-" * 90)
for d in devices:
    print(fmt.format(
        host=d.get("host", "?")[:22],
        os=d.get("os", "?")[:8],
        arch=d.get("arch", "?")[:8],
        profile=d.get("profile", "?")[:16],
        plugins=len(d.get("enabled_plugins") or []),
        mcp=len(d.get("mcp_servers_settings") or d.get("mcp_servers_list") or []),
        skills=len(d.get("skills") or []),
        last=(d.get("last_synced") or "?")[:19],
    ))

# Plugin matrix
all_plugins = sorted({p for d in devices for p in (d.get("enabled_plugins") or [])})
if all_plugins:
    print("\nPLUGINS (✔ = enabled on host)")
    header_hosts = [d.get("host", "?")[:10] for d in devices]
    width = max(len(p) for p in all_plugins)
    print(" " * (width + 2) + " ".join(f"{h:>10}" for h in header_hosts))
    for p in all_plugins:
        cells = []
        for d in devices:
            cells.append("        ✔ " if p in (d.get("enabled_plugins") or []) else "        · ")
        print(f"{p:<{width}}  " + " ".join(cells))
PYEOF
}

cmd_show() {
    local host="${1:-}"
    [[ -z "$host" ]] && { echo "usage: device-snapshot.sh show <host>"; exit 2; }
    local f="$DEVICES_DIR/${host}.json"
    if [[ ! -f "$f" ]]; then
        echo "no snapshot for: $host"
        echo "available:"
        ls "$DEVICES_DIR" 2>/dev/null | sed 's/\.json$//' | sed 's/^/  /'
        exit 1
    fi
    cat "$f"
}

case "${1:-write}" in
    write)  cmd_write ;;
    list)   cmd_list ;;
    show)   shift; cmd_show "$@" ;;
    *)      echo "usage: device-snapshot.sh [write|list|show <host>]"; exit 2 ;;
esac

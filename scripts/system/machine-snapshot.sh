#!/usr/bin/env bash
# Collects comprehensive machine snapshot for Engram/AI context.
# Outputs structured markdown. Run once per machine, pipe or paste into Engram.
# Usage: ./machine-snapshot.sh [--json]

set -euo pipefail

JSON_MODE=0
[[ "${1:-}" == "--json" ]] && JSON_MODE=1

HOSTNAME=$(hostname -s)
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

md() { printf '%s\n' "$@"; }

# ─── Header ───────────────────────────────────────────────────────────────────
md "# Machine Snapshot: $HOSTNAME"
md "_Generated: ${TIMESTAMP}_"
md ""

# ─── OS ───────────────────────────────────────────────────────────────────────
md "## OS"
if command -v lsb_release &>/dev/null; then
    md "- **Distro**: $(lsb_release -ds 2>/dev/null)"
fi
md "- **Kernel**: $(uname -r)"
md "- **Arch**: $(uname -m)"
md "- **Uptime**: $(uptime -p 2>/dev/null || uptime)"
md ""

# ─── CPU ──────────────────────────────────────────────────────────────────────
md "## CPU"
CPU_MODEL=$(grep -m1 "model name" /proc/cpuinfo | cut -d: -f2 | xargs)
CPU_CORES=$(grep -c "^processor" /proc/cpuinfo)
CPU_PHYS=$(grep "cpu cores" /proc/cpuinfo | head -1 | awk '{print $NF}')
CPU_SOCKETS=$(lscpu 2>/dev/null | grep "^Socket(s):" | awk '{print $2}' || echo 1)
L2=$(lscpu 2>/dev/null | grep "L2 cache" | sed 's/.*L2 cache:\s*//' | xargs || echo "?")
L3=$(lscpu 2>/dev/null | grep "L3 cache" | sed 's/.*L3 cache:\s*//' | xargs || echo "?")
md "- **Model**: $CPU_MODEL"
md "- **Sockets**: $CPU_SOCKETS  |  **Cores**: $CPU_PHYS  |  **Threads**: $CPU_CORES"
md "- **L2 cache**: $L2  |  **L3 cache**: $L3"
# Current freq if available
if [[ -f /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq ]]; then
    FREQ=$(awk '{printf "%.1f GHz", $1/1000000}' /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq)
    MAX_FREQ=$(awk '{printf "%.1f GHz", $1/1000000}' /sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_max_freq 2>/dev/null || echo "?")
    md "- **Current freq**: $FREQ  |  **Max freq**: $MAX_FREQ"
fi
md ""

# ─── Load ─────────────────────────────────────────────────────────────────────
md "## Load & Resources"
read -r L1 L5 L15 <<< "$(awk '{print $1,$2,$3}' /proc/loadavg)"
md "- **Load avg (1/5/15m)**: $L1 / $L5 / $L15"
MEM=$(free -h | awk '/^Mem:/{printf "total=%s used=%s free=%s available=%s", $2, $3, $4, $7}')
SWAP=$(free -h | awk '/^Swap:/{printf "total=%s used=%s free=%s", $2, $3, $4}')
md "- **RAM**: $MEM"
md "- **Swap**: $SWAP"
md ""

# ─── RAM slots (dmidecode) ────────────────────────────────────────────────────
if command -v dmidecode &>/dev/null && dmidecode -t memory &>/dev/null 2>&1; then
    DIMM_INFO=$(dmidecode -t memory 2>/dev/null | awk '
        /Memory Device/{ if(size && size!="No Module Installed") print "  - " size " " type " @ " speed " (" mfr " " part ")"; size=""; type=""; speed=""; mfr=""; part="" }
        /^\tSize:/ && !/No Module/{ size=$2" "$3 }
        /^\tType:/ && !/Detail/{ type=$2 }
        /^\tSpeed:/ && /MT\/s/{ speed=$2" "$3 }
        /^\tManufacturer:/{ mfr=$2 }
        /^\tPart Number:/{ part=$2 }
        END{ if(size && size!="No Module Installed") print "  - " size " " type " @ " speed " (" mfr " " part ")" }
    ')
    if [[ -n "$DIMM_INFO" ]]; then
        md "## RAM Modules"
        md "$DIMM_INFO"
        md ""
    fi
fi

# ─── Storage ──────────────────────────────────────────────────────────────────
md "## Storage"
md "\`\`\`"
lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT,MODEL,ROTA 2>/dev/null | grep -v "^loop"
md "\`\`\`"
md ""
md "### Disk Usage"
md "\`\`\`"
df -h --output=source,size,used,avail,pcent,target 2>/dev/null | grep -Ev "tmpfs|devtmpfs|udev|loop|squash" | column -t
md "\`\`\`"
md ""

# ─── GPU ──────────────────────────────────────────────────────────────────────
md "## GPU / Display"
if command -v lspci &>/dev/null; then
    lspci | grep -iE "vga|3d|display" | while IFS= read -r line; do
        md "- $line"
    done
fi
md ""

# ─── Network ──────────────────────────────────────────────────────────────────
md "## Network Interfaces"
md "\`\`\`"
ip -br addr | grep -v "^veth\|^br-\|^docker"
md "\`\`\`"
md ""

if command -v tailscale &>/dev/null; then
    md "### Tailscale"
    md "\`\`\`"
    tailscale status 2>/dev/null | grep -v "^$" | head -30
    md "\`\`\`"
    md ""
fi

# ─── PCI devices ──────────────────────────────────────────────────────────────
md "## PCI Devices"
if command -v lspci &>/dev/null; then
    lspci | grep -iE "ethernet|wireless|wifi|sata|nvme|usb|audio|sound" | while IFS= read -r line; do
        md "- $line"
    done
fi
md ""

# ─── Docker ───────────────────────────────────────────────────────────────────
if command -v docker &>/dev/null && docker info &>/dev/null 2>&1; then
    md "## Docker"
    DOCKER_VER=$(docker version --format '{{.Server.Version}}' 2>/dev/null || echo "?")
    CONTAINER_COUNT=$(docker ps -q | wc -l)
    IMAGE_COUNT=$(docker images -q | wc -l)
    VOLUME_COUNT=$(docker volume ls -q | wc -l)
    md "- **Docker version**: $DOCKER_VER"
    md "- **Running containers**: $CONTAINER_COUNT  |  **Images**: $IMAGE_COUNT  |  **Volumes**: $VOLUME_COUNT"
    md ""

    md "### Stacks (Compose)"
    md "\`\`\`"
    docker compose ls 2>/dev/null || echo "none"
    md "\`\`\`"
    md ""

    md "### Running Containers"
    md "\`\`\`"
    docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}" 2>/dev/null
    md "\`\`\`"
    md ""
fi

# ─── System services ──────────────────────────────────────────────────────────
md "## System Services (notable running)"
if command -v systemctl &>/dev/null; then
    systemctl list-units --type=service --state=running --no-legend 2>/dev/null \
        | grep -Ev "docker|snap|systemd|dbus|network|udev|log|cron|ssh|udisk|polkit|avahi|rtkit|acpid|bluetoo|ModemMa|power|user@|getty|wpa_sup|containerd" \
        | awk '{print "- " $1}' \
        | head -40
fi
md ""

# ─── Samba ────────────────────────────────────────────────────────────────────
if command -v smbstatus &>/dev/null && systemctl is-active smbd &>/dev/null 2>&1; then
    md "## Samba Shares"
    md "\`\`\`"
    testparm -s 2>/dev/null | grep -A2 "^\[" | grep -v "^--$" | head -40
    md "\`\`\`"
    md ""
fi

# ─── SMART disk health (brief) ────────────────────────────────────────────────
if command -v smartctl &>/dev/null; then
    md "## Disk Health (SMART)"
    for disk in $(lsblk -dno NAME | grep -v "^loop\|^mmcblk"); do
        STATUS=$(smartctl -H /dev/$disk 2>/dev/null | grep "overall-health" | awk '{print $NF}')
        [[ -n "$STATUS" ]] && md "- **/dev/$disk**: $STATUS"
    done
    md ""
fi

# ─── Misc ─────────────────────────────────────────────────────────────────────
md "## Misc"
md "- **Hostname**: $HOSTNAME"
md "- **LAN IP**: $(ip -4 addr show | grep -v "127.0.0\|docker\|br-\|veth\|tailscale" | grep "inet " | awk '{print $2}' | head -1)"
md "- **Tailscale IP**: $(tailscale ip -4 2>/dev/null || echo 'n/a')"
if [[ -f ~/.dotfiles/VERSION ]] || [[ -f ~/dotfiles/VERSION ]]; then
    VER_FILE="${HOME}/.dotfiles/VERSION"
    [[ -f ~/dotfiles/VERSION ]] && VER_FILE=~/dotfiles/VERSION
    md "- **Dotfiles version**: $(cat $VER_FILE)"
fi
md "- **Shell**: $SHELL  ($(${SHELL} --version 2>&1 | head -1))"
md ""

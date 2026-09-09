#!/usr/bin/env bash
# =============================================================================
# scripts/install/ssh-superbro.sh — idempotent SSH setup for fleet hosts
# =============================================================================
# MCP agents and Paseo CLI spawn `ssh <host> …`. Without known_hosts entries
# under those aliases, SSH blocks on a yes/no prompt and automation never connects.
#
# Two-part fix, both idempotent:
#   B) ~/.ssh/config blocks with HostName + hardened options
#   C) ssh-keyscan → ~/.ssh/known_hosts (one-time TOFU under Tailscale)
#
# Host definitions: config/fleet-hosts.conf
# Re-running is safe. Unreachable hosts skip keyscan non-fatally.
# =============================================================================

set -euo pipefail

log() { printf "[ssh] %s\n" "$*"; }

if ! command -v ssh-keygen >/dev/null 2>&1 || ! command -v ssh-keyscan >/dev/null 2>&1; then
    log "ssh-keygen/ssh-keyscan missing — skipping"
    exit 0
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
FLEET_CONF="$DOTFILES_DIR/config/fleet-hosts.conf"

if [[ ! -f "$FLEET_CONF" ]]; then
    log "fleet config missing: $FLEET_CONF"
    exit 1
fi

# shellcheck source=config/fleet-hosts.conf
source "$FLEET_CONF"

mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"

ssh_config="$HOME/.ssh/config"
touch "$ssh_config"
chmod 600 "$ssh_config"

write_host_block() {
    local name="$1" address="$2" port="$3" user="$4"
    local begin="# >>> dotfiles:fleet:$name >>>"
    local end="# <<< dotfiles:fleet:$name <<<"
    local block
    block="$(
        cat <<EOF

$begin
Host $name
    HostName $address
    User $user
    Port $port
    StrictHostKeyChecking accept-new
    ServerAliveInterval 15
    ServerAliveCountMax 6
    TCPKeepAlive yes
    ControlMaster auto
    ControlPath ~/.ssh/cm-%C
    ControlPersist 600
$end
EOF
    )"
    if grep -qF "$begin" "$ssh_config"; then
        log "refreshing SSH config block for $name"
        local tmp
        tmp="$(mktemp)"
        awk -v b="$begin" -v e="$end" '
            $0 == b { skip=1; next }
            skip && $0 == e { skip=0; next }
            !skip { print }
        ' "$ssh_config" >"$tmp"
        cat "$tmp" >"$ssh_config"
        rm -f "$tmp"
    else
        log "adding SSH config block for $name"
    fi
    printf '%s\n' "$block" >>"$ssh_config"
    chmod 600 "$ssh_config"
}

keyscan_host() {
    local name="$1"
    local host port lookup

    host="$(ssh -G "$name" 2>/dev/null | awk '/^hostname /{print $2; exit}')"
    port="$(ssh -G "$name" 2>/dev/null | awk '/^port /{print $2; exit}')"
    port="${port:-22}"

    if [[ "$port" == "22" ]]; then
        lookup="$name"
    else
        lookup="[$name]:$port"
    fi

    if [[ -z "$host" || "$host" == "localhost" ]]; then
        log "skipping keyscan for $name (localhost or unresolved)"
        return 0
    fi

    if ssh-keygen -F "$lookup" -f "$known_hosts" >/dev/null 2>&1; then
        log "known_hosts entry for $lookup already present"
        return 0
    fi

    log "scanning $name host key ($host:$port, timeout 5s) …"
    if scan="$(ssh-keyscan -T 5 -p "$port" -H "${host},${name}" 2>/dev/null)" && [[ -n "$scan" ]]; then
        printf "%s\n" "$scan" >>"$known_hosts"
        log "added $name to $known_hosts"
    else
        log "could not reach $name for keyscan — Tailscale up? Re-run: bash scripts/install/ssh-superbro.sh"
    fi
}

known_hosts="$HOME/.ssh/known_hosts"
touch "$known_hosts"
chmod 600 "$known_hosts"

# Remove legacy per-host blocks superseded by fleet blocks.
strip_legacy_block() {
    local begin="$1" end="$2"
    [[ -f "$ssh_config" ]] || return 0
    grep -qF "$begin" "$ssh_config" || return 0
    log "removing legacy SSH block ($begin)"
    local tmp
    tmp="$(mktemp)"
    awk -v b="$begin" -v e="$end" '
        $0 == b { skip=1; next }
        skip && $0 == e { skip=0; next }
        !skip { print }
    ' "$ssh_config" >"$tmp"
    cat "$tmp" >"$ssh_config"
    rm -f "$tmp"
    chmod 600 "$ssh_config"
}

strip_legacy_block "# >>> dotfiles:superbro >>>" "# <<< dotfiles:superbro <<<"
strip_legacy_block "# >>> dotfiles:linuxbro >>>" "# <<< dotfiles:linuxbro <<<"

for entry in "${FLEET_SSH[@]}"; do
    IFS='|' read -r name address port user _profile _push _paseo _notes <<<"$entry"
    [[ "$name" == "mac" ]] && continue
    write_host_block "$name" "$address" "$port" "$user"
    keyscan_host "$name"
done

log "fleet SSH setup complete"

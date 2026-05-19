#!/usr/bin/env bash
# =============================================================================
# scripts/install/ssh-superbro.sh — idempotent SSH setup for superbro
# =============================================================================
# Engram MCPs spawn `ssh superbro …`. Without a known_hosts entry under that
# alias, SSH blocks on a yes/no prompt and the MCP never connects.
#
# Two-part fix, both idempotent:
#   B) ~/.ssh/config block with StrictHostKeyChecking=accept-new (Host superbro)
#   C) ssh-keyscan superbro → ~/.ssh/known_hosts (one-time TOFU under Tailscale)
#
# Re-running is safe: presence checks bail before any write. If superbro is
# unreachable (Tailscale down), C is skipped non-fatally.
# =============================================================================

set -euo pipefail

log() { printf "[ssh] %s\n" "$*"; }

if ! command -v ssh-keygen >/dev/null 2>&1 || ! command -v ssh-keyscan >/dev/null 2>&1; then
    log "ssh-keygen/ssh-keyscan missing — skipping"
    exit 0
fi

mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"

ssh_config="$HOME/.ssh/config"
touch "$ssh_config"
chmod 600 "$ssh_config"

marker_begin="# >>> dotfiles:superbro >>>"
marker_end="# <<< dotfiles:superbro <<<"

write_hardened_block() {
    local host="$1" begin="$2" end="$3"
    local block
    block="$(cat <<EOF

$begin
Host $host
    StrictHostKeyChecking accept-new
    ServerAliveInterval 15
    ServerAliveCountMax 2
    TCPKeepAlive yes
    ControlMaster auto
    ControlPath ~/.ssh/cm-%C
    ControlPersist 60
$end
EOF
)"
    if grep -qF "$begin" "$ssh_config"; then
        log "refreshing hardened SSH config block for $host"
        # Strip existing block (BSD/GNU sed compatible), then append fresh copy.
        local tmp
        tmp="$(mktemp)"
        awk -v b="$begin" -v e="$end" '
            $0 == b { skip=1; next }
            skip && $0 == e { skip=0; next }
            !skip { print }
        ' "$ssh_config" > "$tmp"
        cat "$tmp" > "$ssh_config"
        rm -f "$tmp"
    else
        log "adding hardened SSH config block for $host"
    fi
    printf '%s\n' "$block" >> "$ssh_config"
    chmod 600 "$ssh_config"
}

write_hardened_block superbro "$marker_begin" "$marker_end"
write_hardened_block linuxbro "# >>> dotfiles:linuxbro >>>" "# <<< dotfiles:linuxbro <<<"

known_hosts="$HOME/.ssh/known_hosts"
touch "$known_hosts"
chmod 600 "$known_hosts"

# ssh-keyscan ignores ~/.ssh/config — pull hostname + port from ssh -G.
# Pass `IP,superbro` so the hashed entries match either lookup.
# When port != 22, ssh-keygen -F expects `[host]:port` lookup form.
superbro_host="$(ssh -G superbro 2>/dev/null | awk '/^hostname /{print $2; exit}')"
superbro_port="$(ssh -G superbro 2>/dev/null | awk '/^port /{print $2; exit}')"
superbro_port="${superbro_port:-22}"

if [[ "$superbro_port" == "22" ]]; then
    superbro_lookup="superbro"
else
    superbro_lookup="[superbro]:$superbro_port"
fi

if [[ -z "$superbro_host" ]]; then
    log "ssh -G superbro did not resolve a hostname — is the alias defined?"
elif ssh-keygen -F "$superbro_lookup" -f "$known_hosts" >/dev/null 2>&1; then
    log "known_hosts entry for $superbro_lookup already present"
else
    log "scanning superbro host key ($superbro_host:$superbro_port, timeout 5s) …"
    if scan="$(ssh-keyscan -T 5 -p "$superbro_port" -H "${superbro_host},superbro" 2>/dev/null)" && [[ -n "$scan" ]]; then
        printf "%s\n" "$scan" >> "$known_hosts"
        log "added superbro to $known_hosts"
    else
        log "could not reach superbro for keyscan — Tailscale up? Re-run: bash scripts/install/ssh-superbro.sh"
    fi
fi

# Fleet registry

Canonical machine topology for agents. SSH fields live in `config/fleet-hosts.conf`.
Refresh hardware with `scripts/system/machine-snapshot.sh` per host.

_Last updated: 09-09-2026_

## Summary

| Host | Role | Profile | Tailscale | SSH | Paseo | Git push |
|------|------|---------|-----------|-----|-------|----------|
| **Mac** | Control plane, author | `desktop-full` | yes | — | local daemon | allowed |
| **MonsterBro** | Work engine (WSL) | `wsl` | `100.100.1.255` (`monsterbro`) | `monsterbro` | WSL daemon via `ssh://monsterbro` | allowed |
| **LinuxBro** | Homelab / docker / media | `server-headless` | `100.100.1.100` | `linuxbro` | optional | **never** |
| **SuperBro** | VPS services / janitor | `server-headless` | `100.100.1.50` | `superbro` | optional | **never** |

Browser view: open [`infra/infra.html`](infra.html) locally.

## Per-host detail

### Mac (control plane)

- **Purpose:** Author dotfiles, Cursor/Pi daily driver, Paseo orchestration UI.
- **Paseo:** Local daemon; dispatch remote work with `paseo --host ssh://<host>`.
- **MCP:** Full mcporter catalog; enable dockhand servers on-demand only.
- **Agents:** Enable Paseo tools for delegation; cross-host via CLI `--host`, not injected MCP.

### MonsterBro (work engine)

- **OS:** Windows 11 host + Debian 12 WSL2 (`systemd=true`).
- **Purpose:** Always-on dev box when powered — builds, parallel agents, client repos.
- **Hardware:** Gaming rig (muscle vs LinuxBro NUC); confirm with `machine-snapshot.sh`.
- **Dotfiles:** `PROFILE=wsl`, propagate with `DOTFILES_WORKFLOWS=wsl`.
- **Paseo:** Daemon in WSL; bind `127.0.0.1:6767`; remote via SSH transport from Mac.
- **Providers:** Codex, Claude CLI, Pi, OpenCode — auth stays local in WSL.
- **Caveat:** Sometimes off (gaming). Check `ping -c1 monsterbro` before propagate.

### LinuxBro (homelab)

- **Hardware:** Intel NUC8-class, i5-8259U, 16 GB RAM, ~31 Docker containers.
- **Purpose:** Plex, Immich, *arr, Home Assistant, Traefik, downloaders.
- **MCP:** Serves `dockhand-linuxbro` at `http://100.100.1.100:8092/mcp`.
- **Paseo:** Light chores only — RAM headroom ~6 GB at steady state.
- **Push guard:** Never `git push` from this host.

### SuperBro (VPS)

- **Purpose:** Janitor cron, graphiti, lighter dotfiles mirror, Redis for pi-peer.
- **MCP:** `dockhand-superbro` `:8080`, graphiti health `:8000`.
- **Vault:** `rbw` → `https://vault.superbro.dk`.
- **Push guard:** Never `git push` from this host.

## Security boundaries

| Layer | Rule |
|-------|------|
| Network | Tailscale mesh only for inter-host; no public Paseo binds |
| Paseo | Password required on any non-localhost listen; relay off on servers unless mobile needed |
| SSH | Key auth, ControlMaster, `StrictHostKeyChecking accept-new` via `scripts/install/ssh-superbro.sh` |
| Credentials | Never sync API keys in dotfiles; each host uses local provider auth |
| MCP | mcporter on-demand; dockhand per-host, not global native exposure |
| Git | Push allowed: Mac, MonsterBro only |
| Relay QR | Treat like a password |

## Cross-host collaboration

### Mac orchestrates, remote executes

```bash
paseo --host ssh://monsterbro run --provider codex/gpt-5.4 \
  --cwd ~/Projects/client-repo \
  "Implement X, run tests, summarize diff"
```

Injected Paseo MCP tools operate on the **local** daemon only. Cross-host work uses CLI `--host`.

### Remote MCP without remote shell

Mac agent enables `dockhand-linuxbro` in mcporter → Tailscale to `:8092` → container ops without full SSH.

### Agent messaging

`send_agent_prompt` works within one daemon (same host). Cross-host handoffs use CLI dispatch + Higgins vault notes.

### Higgins handoff

```bash
higgins next "Implement on monsterbro: <task>; search fleet for host context"
```

Agents search before acting: `search("monsterbro paseo fleet")`.

## Paseo agent profiles (suggested)

| Profile | Host | When to use |
|---------|------|-------------|
| `mac-orchestrator` | Mac | Planning, review, cross-host dispatch |
| `monsterbro-build` | MonsterBro | Heavy compiles, parallel implementation agents |
| `linuxbro-infra` | LinuxBro | Docker restarts, homelab health checks |

Configure in Paseo Desktop → Agent profiles with delegation notes.

## MonsterBro bootstrap checklist

### A. Windows host

1. Power: AC = never sleep.
2. Tailscale enrolled; MagicDNS name `monsterbro` resolves from Mac.
3. OpenSSH server; port **27789**; key auth only.
4. Firewall: allow Tailscale interface for SSH + forwarded Paseo (6767) only.

### B. WSL Debian 12

```bash
# /etc/wsl.conf
[boot]
systemd=true
```

```bash
git clone git@github.com:bybrostrom/dotfiles.git ~/dotfiles
echo 'PROFILE=wsl' >> ~/.local-config
DOTFILES_NONINTERACTIVE=1 DOTFILES_WORKFLOWS=wsl ~/dotfiles/bootstrap.sh

npm i -g paseo
paseo daemon set-password
paseo project create ~/dotfiles
paseo provider diagnostic codex --json
paseo provider diagnostic claude --json
```

Daemon config (`~/.paseo/config.json`):

```json
{
  "$schema": "https://paseo.sh/schemas/paseo.config.v1.json",
  "version": 1,
  "daemon": {
    "listen": "127.0.0.1:6767",
    "relay": { "enabled": false },
    "mcp": { "enabled": true }
  },
  "features": { "webUi": { "enabled": true } }
}
```

### C. WSL autostart (systemd user unit)

```ini
# ~/.config/systemd/user/paseo-daemon.service
[Unit]
Description=Paseo daemon
After=network-online.target

[Service]
ExecStart=%h/.local/share/fnm/current/bin/paseo daemon start
Restart=on-failure

[Install]
WantedBy=default.target
```

```bash
systemctl --user enable --now paseo-daemon.service
loginctl enable-linger christian
```

### D. Verify from Mac

```bash
bash ~/dotfiles/scripts/install/ssh-superbro.sh
paseo --host ssh://monsterbro ls
paseo --host ssh://monsterbro run --provider codex/gpt-5.4 \
  --cwd ~/dotfiles "Run ./scripts/doctor.sh; failures only"
```

## Maintenance

```bash
# Refresh host snapshots (run on each machine, commit to Higgins infra/hosts/)
~/dotfiles/scripts/system/machine-snapshot.sh

# Re-apply SSH hardening + known_hosts keyscan
bash ~/dotfiles/scripts/install/ssh-superbro.sh
```

## Related files

| File | Purpose |
|------|---------|
| `config/fleet-hosts.conf` | SSH + role source of truth |
| `infra/infra.html` | Browser-readable fleet dashboard |
| `scripts/install/ssh-superbro.sh` | Idempotent SSH blocks + keyscan |
| `zsh/03-aliases.zsh` | Interactive `superbro`, `linuxbro`, `monsterbro` |
| `.agents/skills/dotfiles-update/SKILL.md` | Propagation commands per host |

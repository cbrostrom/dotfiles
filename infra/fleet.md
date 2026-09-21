# Fleet registry

Canonical machine topology for agents. SSH fields live in `config/fleet-hosts.conf`.
Refresh hardware with `scripts/system/machine-snapshot.sh` per host.

_Last updated: 10-09-2026_

## Summary

| Host | Role | Profile | Tailscale | SSH / RDP | Paseo | Git push |
|------|------|---------|-----------|-----------|-------|----------|
| **Mac** | Control plane, author | `macos` | yes | — | local daemon | allowed |
| **CloudBro** | Linux development box | `cloudbro` | pending | pending | Pi via Paseo | dotfiles only |
| **MonsterBro (WSL)** | Work engine | `wsl` | `100.100.1.255` (`monsterbro-wsl`) | `monsterbro` / `monsterbro-wsl` `:27789` | WSL daemon via `ssh://monsterbro` | allowed |
| **MonsterBro (Win)** | WSL host / desktop | — | `100.100.1.250` (`monsterbro`) | RDP `:3389` | — | — |
| **LinuxBro** | Homelab / docker / media | `server` | `100.100.1.100` | `linuxbro` | optional | **never** |
| **SuperBro** | VPS services / janitor | `server` | `100.100.1.50` | `superbro` | optional | **never** |

Browser view: open [`infra/infra.html`](infra.html) locally.

## Per-host detail

### Mac (control plane)

- **Purpose:** Author dotfiles, Cursor/Pi daily driver, Paseo orchestration UI.
- **Paseo:** Local daemon; dispatch remote work with `paseo --host ssh://<host>`.
- **MCP:** Full mcporter catalog; enable dockhand servers on-demand only.
- **Agents:** Enable Paseo tools for delegation; cross-host via CLI `--host`, not injected MCP.

### MonsterBro (Windows host + WSL work engine)

One physical machine, two Tailscale identities:

| Layer | Tailscale name | IP | Access | Role |
|-------|----------------|-----|--------|------|
| Windows 11 | `monsterbro` | `100.100.1.250` | RDP `:3389` | Desktop, gaming, WSL host |
| WSL Debian 12 | `monsterbro-wsl` | `100.100.1.255` | SSH `:27789` | Dotfiles, builds, Paseo daemon |

- **Purpose:** Always-on dev box when powered — builds, parallel agents, client repos (WSL).
- **Hardware:** Gaming rig (muscle vs LinuxBro NUC); confirm with `machine-snapshot.sh`.
- **Dotfiles:** apply with `~/dotfiles/install.sh wsl`.
- **SSH:** Dotfiles alias `monsterbro` targets WSL (`.255:27789`); `monsterbro-wsl` is the same host for Tailscale name parity.
- **RDP:** Mac Microsoft Remote Desktop → `monsterbro` or `100.100.1.250:3389` (Windows side; enable Remote Desktop + Tailscale firewall rule manually).
- **Paseo:** Daemon in WSL; bind `127.0.0.1:6767`; remote via SSH transport from Mac.
- **Providers:** Pi plus explicitly enabled providers; OpenCode Go is configured inside Pi.
- **Caveat:** Sometimes off (gaming). Check `ping -c1 monsterbro-wsl` before propagate.

### LinuxBro (homelab)

- **Hardware:** Intel NUC8-class, i5-8259U, 16 GB RAM, ~31 Docker containers.
- **Purpose:** Plex, Immich, *arr, Home Assistant, Traefik, downloaders.
- **MCP:** Serves `dockhand-linuxbro` at `http://100.100.1.100:8092/mcp`.
- **Stack ops:** Redeploy via Dockhand MCP only — see skill `dockhand` (`.agents/skills/dockhand/SKILL.md`). Compose mirror: `~/.config/superbro-compose/linuxbro/`; live path on host: `~/.config/appdata/dockhand/compose-repo/linuxbro/`.
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
| Git | Push allowed: Mac, MonsterBro; CloudBro dotfiles repo only (`~/.claude/push-whitelist.txt`, `guard-git-push` hook) |
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
2. Tailscale enrolled; MagicDNS `monsterbro` → `.250` (Windows), `monsterbro-wsl` → `.255` (WSL).
3. **RDP:** Settings → System → Remote Desktop → enable; allow `:3389` on Tailscale interface.
4. OpenSSH server (forwards into WSL); port **27789**; key auth only; `AllowTcpForwarding yes` for `paseo --host ssh://…`.
5. Firewall: allow Tailscale interface for SSH, RDP, and forwarded Paseo (6767) as needed.

### B. WSL Debian 12

```bash
# /etc/wsl.conf
[boot]
systemd=true
```

```bash
git clone git@github.com:cbrostrom/dotfiles.git ~/dotfiles
echo 'PROFILE=wsl' >> ~/.local-config
~/dotfiles/install.sh wsl

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

## Dotfiles fleet updates

The Mac control plane updates the unique targets in `FLEET_DOTFILES_HOSTS`.
`monsterbro-wsl` is intentionally excluded because it aliases `monsterbro`.
CloudBro should be added only after its canonical `FLEET_SSH` entry and key-only
SSH access exist.

```bash
./scripts/system/fleet-update.sh --list
./scripts/system/fleet-update.sh
./scripts/system/fleet-update.sh --host linuxbro --host superbro
```

Each host transaction acquires a non-blocking `flock`, refuses a dirty,
detached, divergent, or locally-ahead checkout, fetches and fast-forwards its
tracking branch, previews Stow, runs `install.sh`, applies an optional tracked
`setup/hosts/<name>.sh`, and runs `scripts/doctor.sh`. One failure does not stop
later hosts. Logs live under `~/.local/state/dotfiles/fleet/<run>/` on the
control plane.

Failures produce a terminal summary and a macOS notification. Set
`DOTFILES_FLEET_NOTIFY_CMD` to an executable for another notification channel;
it receives `failure`, the summary, and the run directory. Store webhook tokens
and credentials outside this repository.

Host hooks are for idempotent, tracked, non-secret configuration. Runtime state,
credentials, and genuine machine-local overrides remain outside Git. See
`setup/hosts/README.md` for the hook contract.

## Maintenance

```bash
# Refresh host snapshots (run on each machine, commit to Higgins infra/hosts/)
~/dotfiles/scripts/system/machine-snapshot.sh

# Re-apply SSH hardening + known_hosts keyscan
bash ~/dotfiles/scripts/install/ssh-superbro.sh
```

## Recovery playbook (LinuxBro 2026-09-20)

- **No more load-driven reboots.** Watchdog runs `softdog` at
  `/dev/watchdog1` with thresholds 120/90/60; the `immich-sync.service`
  crash loop that fed the old watchdog trips is retired (unit renamed
  `.disabled`). See `docs/server-provisioning.md` §9.
- **Boot-order repair.** `linuxbro-boot-repair.service` re-attaches Docker
  containers whose endpoints failed at boot; check
  `journalctl -u linuxbro-boot-repair` when you see unreachable services or
  530s on tunnel routes. See `docs/server-provisioning.md` §10.
- **WUD upgrader.** Runs `9.1.0`, watches containers, auto-updates with
  `wud.trigger.exclude=docker.local` on itself + watchdog. UI at
  `wud-lab.superbro.dk` (Tailscale-only). Compose canonical in Dockhand
  stack `wud` (not the live path outside `_tooling/wud`).
- **Dockhand rule.** Never raw `docker compose up` over SSH — always via
  `dockhand-linuxbro` MCP (`update_stack_compose`, `restart_stack`,
  `restart_container`, ...).
- **`repo-sync` intentionally stopped** on LinuxBro until config corrected —
  do not start it with automation.

## Related files

| File | Purpose |
|------|---------|
| `config/fleet-hosts.conf` | SSH, role, and unique update-target source of truth |
| `infra/infra.html` | Browser-readable fleet dashboard |
| `scripts/install/ssh-superbro.sh` | Idempotent SSH blocks + keyscan |
| `scripts/system/fleet-update.sh` | Fleet controller, logs, summaries, and alerts |
| `scripts/system/fleet-apply.sh` | Streamed, locked remote update transaction |
| `setup/hosts/README.md` | Optional tracked host-configuration contract |
| `zsh/03-aliases.zsh` | Interactive `superbro`, `linuxbro`, `monsterbro` |
| `stow/agents/.agents/skills/dotfiles-update/SKILL.md` | Safe local and fleet update workflow |

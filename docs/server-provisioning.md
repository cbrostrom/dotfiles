# Server provisioning guide

One page per Debian 13 host (CloudBro, LinuxBro, SuperBro). Days count in
commands, not explanations.

## 1. Prerequisites

```sh
sudo apt update
sudo apt install -y git curl stow zsh build-essential locales jq
```

## 2. Login shell

Debian ships `bash` as the default. Make `zsh` the login shell:

```sh
grep -q zsh /etc/shells || echo "$(command -v zsh)" | sudo tee -a /etc/shells
chsh -s "$(command -v zsh)"
```

## 3. Locale

macOS SSH clients forward `LC_ALL=en_US.UTF-8`; Debian 13 images do not ship
that locale, which makes every session print `setlocale` warnings:

```sh
echo "en_US.UTF-8 UTF-8" | sudo tee -a /etc/locale.gen
sudo locale-gen
locale -a | grep -i en_us   # verify
```

`scripts/install/debian.sh` performs this automatically.

## 4. Clone and apply the profile

```sh
git clone https://github.com/cbrostrom/dotfiles ~/system/dotfiles
cd ~/system/dotfiles

./stow.sh plan <profile>     # always review before applying
./install.sh <profile>
./scripts/doctor.sh          # must report zero errors
```

Profiles:

| Host    | Profile   | What it wires              |
| ------- | --------- | -------------------------- |
| CloudBro| `cloudbro`| Paseo (loopback) + Pi dev box |
| LinuxBro| `server`  | lean shell, Git, CLI, agent policy, Pi (+ higgins/rtk/deja) |
| SuperBro| `server`  | lean shell, Git, CLI, agent policy, Pi (+ higgins/rtk/deja) |

### Git credentials

`install.sh` seeds `~/.gitconfig.local` from `.gitconfig.local.example` on
first run. Before cloning any private repo, edit it: uncomment the
**GitHub credential helper** block (resolves `gh` from PATH, works on macOS
and Linux), then run `gh auth login`. Skip this and every HTTPS clone/push
falls back to an interactive username prompt that hangs non-interactive
sessions (pi package installs, CI, `pi-extensions.sh`).

## 5. Shell extras (prompt, fonts)

`starship` is not in Debian's repos. The cross-platform installer handles it:

```sh
./scripts/install/starship.sh
exec zsh
```

Nerd-Font icons render on the **client terminal**, not the host. Connect from a
Mac running Ghostty and the fonts are already there — install nothing on the
server for icons.

## 6. CloudBro extras

CloudBro is a Paseo + Pi development box. After the profile:

```sh
./install.sh cloudbro
```

`install.sh` is idempotent and does everything: bootstraps `fnm` plus the
latest Node.js if npm is missing (`scripts/install/fnm.sh`), installs the npm
globals `pi` and `paseo` (`scripts/install/npm-globals.sh`), and wires the
providers. Rerun it any time; new Node versions install via:

```sh
latest="$(fnm ls-remote | tail -1)"; fnm install "$latest" && fnm default "$latest"
```

```sh
pi --version
paseo --version
```

The daemon starts on loopback with the relay disabled. Connect clients over
SSH or Tailscale; review the connectivity docs before enabling the relay.

## 7. Verification

```sh
./scripts/doctor.sh
paseo daemon status --json        # CloudBro only
paseo provider diagnostic pi --json
zsh -l -c 'echo $ZSH_VERSION'
locale -a | grep -i en_us
```

## 8. Troubleshooting

**`cannot stow ... since neither a link nor a directory`** — a regular file
exists where Stow wants a link. Back it aside, re-apply:

```sh
mv ~/.gitconfig ~/.gitconfig.pre-stow
./stow.sh apply <profile>
```

Compare the backup for host-specific values before deleting it.

## 9. Watchdog policy (LinuxBro + server profile)

The Linux software `watchdog` daemon reboots the host when its probes fail.
Historically it used the motherboard `iTCO_wdt` (15 s window) with load
thresholds tuned for upstream boilerplate (24/18/12), and it rebooted the party
whenever the 15-minute load average stayed above 12 for 65 seconds. After the
2026-09-20 incident (immich-sync crash loop pinning load ~13, watchdog reboot
storm), the watchdog is deliberately de-fanged.

Policy:

- **Module:** `softdog` (`/etc/default/watchdog`: `watchdog_module="softdog"`,
  `run_watchdog=1`, `run_wd_keepalive=1`).
- **Device:** `/etc/watchdog.conf` -> `watchdog-device = /dev/watchdog1`
  (`watchdog1` identity `Software Watchdog`; `watchdog0` is the motherboard
  `iTCO_wdt`). Keep the softdog margins: 120/90/60.
- **Purpose:** cover genuine hangs (`ping` probes to upstream routers plus the
  uptime-kuma heartbeat file donate as file feeds), never punish heavy
  legitimate workloads.
- **Never restart `watchdog` without `run_wd_keepalive=1`** — with `iTCO_wdt`
  now no longer fed, softdog owns boot recovery; a stop must not leave the
  box in the 15-second hardware re-arm window.
- **immich-sync.service is retired.** The unit file is renamed to
  `/etc/systemd/system/immich-sync.service.disabled` because it uses
  `/var/run` (tmpfs, no `RuntimeDirectory=`) and crash-looped forever with
  restart counter 650+, feeding the old watchdog trips. Replaced by
  `immich-backup.service` (host-side dump in `~/.cloudbro/backup-scripts/`)
  where automatic operation is desired.

Apply on a Debian 13 server:

```sh
sudo modprobe softdog
sudo tee -a /etc/default/watchdog >/dev/null <<'EOF'
watchdog_module="softdog"
run_watchdog=1
run_wd_keepalive=1
EOF
sudo tee -a /etc/watchdog.conf >/dev/null <<'EOF'
watchdog-device = /dev/watchdog1
max-load-1   = 120
max-load-5   = 90
max-load-15  = 60
EOF
sudo systemctl restart watchdog
systemctl is-active watchdog   # expect active
lsmod | grep softdog           # expect softdog loaded
sudo -n journalctl -u watchdog -n 5 --no-pager | grep identity   # expect Software Watchdog
```

## 10. Docker boot-order repair (LinuxBro + server profile)

Known defect: at boot, Docker starts containers before their configured
bridge/overlay endpoints exist; the attach fails, Docker does not retry, and
the container stays `running` while unreachable (no network). Fix in two
layers:

1. **Host-level repair unit** — created 2026-09-20 on LinuxBro as
   `linuxbro-boot-repair.service` :

   ```sh
   sudo tee /usr/local/sbin/docker-network-repair.sh >/dev/null <<'EOS'
   #!/bin/bash
   # Re-attach Docker containers that booted without their configured network endpoint.
   LOG_TAG=boot-repair
   sleep 20
   IFS=$'\n' rows=($(docker ps -q | xargs -r docker inspect --format '{{.Id}}|{{.Name}}|{{.HostConfig.NetworkMode}}|{{range $k,$v := .NetworkSettings.Networks}}{{$k}}{{end}}' 2>/dev/null))
   for r in "${rows[@]}"; do
     name=$(echo "$r" | cut -d'|' -f2 | sed 's#^/##')
     mode=$(echo "$r" | cut -d'|' -f3)
     nets=$(echo "$r" | cut -d'|' -f4)
     case "$mode" in host|none|default|container:*) continue;; esac
     [ -z "$nets" ] && { echo "[$(date -Is)] reattaching $name -> $mode"; docker network connect "$mode" "$name"; }
   done
   EOS
   sudo chmod +x /usr/local/sbin/docker-network-repair.sh
   sudo tee /etc/systemd/system/linuxbro-boot-repair.service >/dev/null <<'EOS'
   [Unit]
   Description=Re-attach Docker containers missing their configured network endpoints at boot
   After=docker.service
   Requires=docker.service
   After=network-online.target

   [Service]
   Type=oneshot
   TimeoutStartSec=180
   ExecStart=/usr/local/sbin/docker-network-repair.sh

   [Install]
   WantedBy=multi-user.target
   EOS
   sudo systemctl daemon-reload
   sudo systemctl enable linuxbro-boot-repair.service
   ```

2. **Stack-level anchor:** compose files under
   `~/.config/appdata/dockhand/compose-repo/linuxbro/<stack>/` must declare the
   networks they reference, e.g.:

   ```yaml
   networks:
     wud_default: {}
     traefik:
       external: true
   ```

   Missing explicit declarations are the root of the same boot defect at
   compose level; never rely on past `docker network connect` as config.

**Rule: Docker mutations on Dockhand hosts always go through the Dockhand MCP
(`dockhand-linuxbro` / `dockhand-superbro`); never raw `docker *` or
`docker compose *` via SSH. Read-only diagnostics and host-level systemd
changes remain fine over SSH.**

## 11. Fleet recovery playbook (LinuxBro)

If services report offline/unreachable (530s on public routes, 000 on
Tailscale probes):

1. `sudo journalctl -b -1 | tail -200` — look for `watchdog` load-average
   trigger (pre-fix) or power/panic causes.
2. `sudo /usr/local/sbin/docker-network-repair.sh` — re-attach endpoints.
3. `docker ps -a` — spot `Created`-stuck containers; start them.
4. WUD compose lives at `~/.config/appdata/dockhand/compose-repo/linuxbro/_tooling/wud/docker-compose.yml`;
   auth via stack variables `ADMIN_USER` / `ADMIN_PASS` feeding
   `WUD_AUTH_ADMIN_USER` / `WUD_AUTH_ADMIN_PASSWORD`.
5. `repo-sync` stays stopped (config intentionally disabled).

**`GNU Stow is required`** — run `./scripts/install/debian.sh <profile>` first.

**setlocale warnings persist** — the locale line in `/etc/locale.gen` exists
but was not generated; rerun `sudo locale-gen` and re-login.

# LinuxBro — system audit (2026-05-12)

Snapshot of hardware, services, AI tooling, and optimisation candidates. Source-of-truth for Engram + Graphiti once MCPs are registered locally.

## Hardware

| Field | Value |
|---|---|
| Host | `LinuxBro` (Debian 12 bookworm, kernel 6.1.0-40-amd64) |
| Firmware | UEFI |
| CPU | Intel i5-8259U (CoffeeLake-U) — 4c/8t, 2.3 GHz base, 3.8 GHz max |
| GPU | Intel Iris Plus 655 (QSV-capable, used by Plex transcode) |
| RAM | 16 GB DDR4 (15.5 GiB usable, 6.4 GiB available at audit time) |
| Swap | 976 MiB on LVM `LinuxBro-vg-swap_1` — undersized for 16 GB box |
| Wi-Fi | Intel Cannon Point-LP CNVi 9460/9560 (currently `DOWN`) |
| Bluetooth | Intel 9460/9560 |
| LAN | `eno1` 192.168.1.100/24, default via 192.168.1.1 |
| Tailscale | `tailscale0` 100.100.1.100/32 (matches CLAUDE.md keyword routing) |

NUC-class chassis (i5-8259U → likely NUC8i5BEH). 8 CPUs reported, ~95 % scaling at audit time.

## Storage

| Device | Size | FS | Mount | Notes |
|---|---|---|---|---|
| `sda` Samsung 860 EVO M.2 250 GB | 232.9 G | LVM (ext4) | `/` (227 G, **46 % used**, 118 G free) | Root + `/boot` (vfat ESP + ext2). Headroom OK. |
| `sda2` | 488 M | ext2 | `/boot` | **46 % used, 236 M free** — tight; old kernel waste below. |
| `sdb` Generic 1.8 TB HDD | 1.8 T | NTFS | **unmounted** | `sdb1` not in fstab. Legacy Windows drive — repurpose target. |
| `sdc` 1.8 TB | 1.8 T | ext4 | `/media/2tb` (78 G used, **5 %**) | Lots of headroom. |
| `sdd` 8 TB | 7.3 T | ext4 | `/media/8tb` (3.1 T used, **45 %**) | |
| `sde` 4 TB | 3.6 T | ext4 | `/media/4tb` (2.8 T used, **83 %**) | **Watch — fills first.** |
| `mmcblk0` SD | 7.4 G | exFAT | unmounted | Forgotten card. |

`/etc/fstab` mounts `2tb/4tb/8tb` by UUID. `sdb1` (NTFS, 1.8 T) has no entry — orphaned.

## Tailnet (cbrostrom@)

```
100.100.1.40   routerbro
100.100.1.50   superbro       (active; Engram, Graphiti, Dockhand MCP host)
100.100.1.100  linuxbro       (this host)
100.100.1.200  steambro       (offline 28d)
100.100.1.250  monsterbro
100.100.1.60   ipad-pro       (offline 84d)
100.100.1.70   iphonebro
…
```

## Docker — 34 containers across 11 compose projects

| Project | Containers |
|---|---|
| `infrastructure` | `traefik`, `portainer`, `portaineragent`, `dockerproxy`, `uptimekuma`, `filebrowser`, `syncthing`, `codeserver` |
| `media-core` | `plex`, `sonarr`, `radarr`, `lidarr`, `bazarr`, `prowlarr`, `tautulli` |
| `downloaders` | `gluetun` (healthy), `qbittorrentvpn`, `sabnzbdvpn`, `metube`, `slskd` |
| `music` | `navidrome`, `music-assistant` **(unhealthy)**, `metadata-remote` |
| `immich` | `immich_server`, `immich_machine_learning`, `immich_postgres` (pgvector), `immich_redis` (valkey) |
| `personal` | `homeassistant`, `homeassistant-postgres` |
| `romm` | `romm`, `romm-db` (mariadb) |
| `backup` | `rclone-backup` (alpine) |
| `vector` | `vector-cloudbro` (Timberio Vector — log shipping) |
| `setup` | (Traefik cert/cache volumes) |
| `v-rising` | `vrising` — **42 % CPU, 1.96 GiB RSS** (Wine-based game server) |

Docker space: 26.55 GB images (3.68 GB reclaimable), 14.85 GB volumes (1.41 GB reclaimable). 2 dangling images. 3 unnamed dangling volumes (hex IDs). Daemon v28.5.1.

### `music-assistant` health-check failing

Health-check uses `wget` against `http://192.168.1.100:8095/` with HEAD method. The webserver logs `Received unhandled HEAD request to /` every 30 s. Fix: change healthcheck to `wget -qO- http://localhost:8095/info` (GET) or use `curl -fsS`.

## AI tooling found (non-Claude — cleanup targets)

| Tool | Path | Size | Notes |
|---|---|---|---|
| **Cursor IDE** server | `~/.cursor-server/` | **1.3 GB** | VS Code Remote bits for Cursor connecting to linuxbro. |
| **Cursor IDE** config | `~/.cursor/` | 24 MB | Settings + cache. |
| Cursor launcher | `~/.local/bin/cursor` (alias) | small | |
| **cursor-agent** | `~/.local/bin/cursor-agent` → `~/.local/share/cursor-agent/` | **496 MB** | Cursor's terminal agent. |
| **Codex** | `~/.codex/` | 28 KB | Config + memories left; binary already absent. Orphan. |
| **Gemini CLI** | `/home/linuxbrew/.linuxbrew/bin/gemini` | — | `gemini-cli` Homebrew formula. Drags node + python@3.14. |
| Linuxbrew root | `/home/linuxbrew/` | **1.2 GB** | Only formula installed is `gemini-cli`. Remove brew entirely if no other reason to keep it. |
| `snap code` | `/snap/code` | ~380 MB × 2 revs | VS Code via snap — VSCodium preferred per dotfiles `modules.conf`. |

**Claude state on linuxbro**: `~/.claude/` present (settings, plugins dir). `~/.local/bin/claude → versions/2.1.139`. `claude mcp list` shows only the claude.ai-managed web MCPs (Slack, Notion, etc.) — **all the Tailscale-only MCPs from `dotfiles/.claude/mcp-servers.list` (engram-personal, engram-work, graphiti, mcp-dockhand-linuxbro, docker-superbro, …) are NOT registered locally**. Dotfiles bootstrap hasn't been run here yet.

## Optimisation targets

### High value, low risk

1. **Snap removal** — Debian native; 13 GB on `/snap`, 4.1 GB on `/var/lib/snapd/snaps`. 8 disabled snap revisions. VSCodium replaces snap-`code`; Firefox is `firefox-esr` in Debian apt. Reclaim ~17 GB.
2. **Journald cap** — 2.6 GB on disk. `journalctl --vacuum-size=500M` reclaims ~2 GB. Then set `SystemMaxUse=500M` in `/etc/systemd/journald.conf`.
3. **Old kernel** — `linux-image-6.1.0-23-amd64` still in `/boot` (`/boot` 46 % full). `apt purge linux-image-6.1.0-23-amd64` frees ~80 MB and breathing room.
4. **Apt cache** — 244 MB in `/var/cache/apt`. `apt-get clean`.
5. **Docker reclaim** — `docker image prune` (3.68 GB), inspect 3 unnamed dangling volumes before pruning.
6. **Linuxbrew + Cursor-server** — 1.2 GB + 1.3 GB + 496 MB = ~3 GB once AI cleanup completes.

### Tuning

7. **VM tuning** — `vm.swappiness=1` (currently low — good), `vm.vfs_cache_pressure=100` (default). Given heavy IO from Plex/Immich/torrent, consider `vfs_cache_pressure=50` to favour cached dentries.
8. **Swap size** — 976 MiB on a 16 GB box used as a server is fine for headroom but tiny. Optional: grow to 2-4 GiB on the LVM volume if you ever see swap pressure.
9. **Tighter dockerproxy ACL** — `dockerproxy` exposes 2375 on `0.0.0.0`. Verify it's only reachable inside `traefik`/internal nets; bind to `127.0.0.1` if Portainer is the only consumer.

### Cleanup leftovers

10. **`dropbox@fred.service` failing** — `fred` user no longer exists; only `christian` (UID 1000). Disable: `systemctl disable dropbox@fred.service` and check whether `dropbox@christian.service` is still needed.
11. **`/opt/sa`** — empty directory owned root. Created 2024-07-30. Safe to `rmdir`.
12. **Wi-Fi** — `wlp0s20f3` is `DOWN`. If wired-only by design, mask `wpa_supplicant` to save a daemon.
13. **`sdb` NTFS** — 1.8 TB unused. Reformat ext4 and add to fstab if you want it as a backup target, or unplug.

## Important services to preserve

These warrant zero-downtime handling during any cleanup:

- `traefik` (terminates 80/443) — every other web service depends on it.
- `gluetun` + `qbittorrentvpn` + `sabnzbdvpn` — VPN-gated downloader chain; restarting `gluetun` breaks the others' netns.
- `immich_*` (4 containers) — photo backup; postgres uses pgvector for ML embeddings.
- `homeassistant` + `homeassistant-postgres` — home automation.
- `plex` + `*arr` + `tautulli` — media.
- `vrising` — game server (high resource use).
- `vector-cloudbro` — log shipping to cloud sink.
- `rclone-backup` — offsite backup runner.

## Cleanup log (2026-05-12)

Executed in this session:

- ✅ Removed Cursor IDE remote server (`~/.cursor-server`, 1.3 GB).
- ✅ Removed Cursor settings (`~/.cursor`, `~/.config/cursor`).
- ✅ Removed Cursor launcher shim (`~/.local/bin/cursor`) and agent symlinks (`cursor-agent`, `agent`).
- ✅ Removed cursor-agent install (`~/.local/share/cursor-agent`, 496 MB).
- ✅ Removed Codex orphan config (`~/.codex`).
- ✅ Uninstalled `gemini-cli` + ran `brew autoremove` — Cellar is empty, no brew leaves.
- ≈ **2.8 GB reclaimed**. Claude binary `v2.1.140` untouched.

Dotfiles note: `zsh/05-integrations.zsh` keeps the cursor alias logic but degrades to no-op since the binary is gone — leave it for portability across other machines.

## Pending follow-ups (need sudo / interactive)

1. **Linuxbrew full removal** (frees the remaining 257 MB and reclaims `/home/linuxbrew`):
   ```sh
   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/uninstall.sh)" --force
   sudo rm -rf /home/linuxbrew
   ```
2. **`music-assistant` healthcheck fix.** Compose is Portainer-managed at `/home/christian/.config/appdata/portainer/compose/9/docker-compose.yml` (root-owned). Replace the failing healthcheck (currently `wget --no-verbose --tries=1 --spider http://192.168.1.100:8095/`) with a GET probe, e.g.:
   ```yaml
   healthcheck:
     test: ["CMD-SHELL", "wget -qO- http://localhost:8095/info || exit 1"]
     interval: 30s
     timeout: 10s
     start_period: 60s
     retries: 3
   ```
   Then redeploy the stack from Portainer (or `sudo docker compose -f /…/9/docker-compose.yml up -d`).
3. **Inspect `sdb1` (1.8 TB NTFS) before reformatting:**
   ```sh
   sudo mkdir -p /mnt/sdb-inspect
   sudo mount -t ntfs-3g -o ro /dev/sdb1 /mnt/sdb-inspect
   du -shc /mnt/sdb-inspect/* 2>/dev/null | sort -h | tail -20
   sudo umount /mnt/sdb-inspect && sudo rmdir /mnt/sdb-inspect
   ```
4. **Tailscale SSH auth** so the next session can ssh `superbro` non-interactively and push the audit into Engram (`mem_save hosts/linuxbro/audit-2026-05-12`).
5. **Register local MCPs** by running `~/dotfiles/bootstrap.sh` — installs `engram-personal`, `engram-work`, `graphiti`, `mcp-dockhand-linuxbro`, `docker-superbro/linuxbro` per `mcp-servers.list`.
6. **Then** plan Portainer → Dockhand migration (separate task).

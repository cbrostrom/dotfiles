# Tailnet Access Plan — Spec for Dev

Status: **Approved spec** — decisions locked 21-09-2026. Implementation happens phase by phase, each phase approved separately before execution.

Sources: `config/fleet-hosts.conf`, `infra/fleet.md`, `scripts/install/ssh-superbro.sh`, `scripts/system/ssh-agent-setup.sh`, live `tailscale status`, Tailscale docs (SSH, policy file, tags/auth keys). Companion visual: `docs/tailnet-access-plan.html`.

---

## 0. Locked decisions

| # | Decision |
|---|----------|
| D1 | Fleet roles: Mac = pilot (control plane). MonsterBro Windows = pilot too; Paseo/Pi run inside WSL. MonsterBro WSL = workstation/work engine. LinuxBro, SuperBro, CloudBro = servers. CloudBro = **orchestrator** (always-online maintenance of LinuxBro + SuperBro). |
| D2 | SSH port **27789 everywhere**, including CloudBro. Hygiene (less bot noise, cleaner logs), not hardening. |
| D3 | SuperBro public-IP SSH (:22) closes after tailnet access is verified. Tailscale SSH recovery is enabled **before** the public path closes (execution order enforces this). |
| D4 | Tailscale SSH = break-glass recovery path. `check` mode (periodic re-auth). Works from any personal device, including iPhone/iPad (untagged user devices — tagged devices cannot use check mode). |
| D5 | Personal devices untagged: Mac, iPhone, iPad, MonsterBro (Windows). Servers tagged `tag:server`. CloudBro tagged `tag:orchestrator` (distinct, narrower). |
| D6 | Web UIs reachable from pilots (Mac, iPhone, iPad, MonsterBro) by `ip:port` for now; Tailscale Serve/MagicDNS is a later improvement track. |
| D7 | CloudBro holds agent keys only — no human key, no long-lived secrets. Low-privilege `agent@` user on target servers. Rebuildable box. |
| D8 | Structural containment: `tag:server` → anything = denied. Replaces the old ad-hoc "keep SuperBro out" wall. |
| D9 | One keypair per source host (human) + separate agent keys per host. Git-hosting keys never used for server login. |
| D10 | Dashboard: own minimal static HTML generated from `fleet-hosts.conf` + live probes. NetBird itself rejected (would replace Tailscale). |

## 1. Fleet inventory (target state)

| Host | Role | Tag | Tailscale IP | SSH port | Human key | Agent key |
|---|---|---|---|---|---|---|
| Mac (`akqamacbook`) | pilot / control plane | — (user device) | 100.100.1.20 | — | `id_ed25519_mac` | `agent_mac_ed25519` |
| MonsterBro Windows (`monsterbro`) | pilot (desktop/RDP) | — (user device) | 100.100.1.250 | — (RDP :3389) | n/a (RDP) | n/a |
| MonsterBro WSL (`monsterbro-wsl`) | workstation / work engine | `tag:server` | 100.100.1.255 | 27789 | `id_ed25519_monsterbro` | `agent_monsterbro_ed25519` |
| LinuxBro (`linuxbro`) | server NUC, homelab | `tag:server` | 100.100.1.100 | 27789 | `id_ed25519_linuxbro` | `agent_linuxbro_ed25519` |
| SuperBro (`superbro`) | server VPS (Contabo) | `tag:server` | 100.100.1.50 | 27789 | `id_ed25519_superbro` | `agent_superbro_ed25519` |
| CloudBro (`cloudbro`) | **orchestrator** devbox | `tag:orchestrator` | 100.100.1.11 | 27789 | none | `agent_cloudbro_ed25519` |
| iPhone / iPad | pilot (mobile) | — (user devices) | .70 / .60 | — (Tailscale app SSH) | n/a | n/a |

Out of scope but noted: `higgins-writer` (.33, `debian@`, `id_ed25519`) — fold into agent-key model later or leave as-is; `routerbro`, `steambro` (offline).

## 2. ACL matrix (the graph, as policy)

Default-deny underneath. Every arrow is an explicit grant.

| Source | Destination | Grants |
|---|---|---|
| `group:pilots` (Mac, iPhone, iPad, MonsterBro Windows) | `tag:server` | SSH :27789; web UI ports (dockhand 8080/8092, Plex, Immich, *arr, WUD); RDP :3389 → monsterbro/.250 |
| `autogroup:member` via Tailscale SSH, `check` mode | `tag:server` | Break-glass SSH, users `autogroup:nonroot` + `root`, periodic re-auth |
| `tag:orchestrator` (CloudBro) | `tag:server` (LinuxBro, SuperBro) | SSH :27789, dockhand MCP :8080/:8092 only |
| `tag:server` | anything | **nothing** — structural containment (D8) |
| `tag:server` → `tag:server` | — | **nothing** — no lateral movement between servers |

Notes:

- MonsterBro WSL is a `tag:server` member but also needs outbound pilot-style SSH to servers (it runs agents). Model: add `monsterbro-wsl` to an explicit grant entry rather than widening `tag:server`; exact policy-file wording is a Phase 4 detail.
- Verify in Tailscale admin console that old SuperBro node (pre-compromise) is deleted — no stale node keys. Precondition: confirm SuperBro was rebuilt post-incident.
- Use the policy file `tests` section to assert allow/deny pairs before applying.

## 3. Security model

### Blast-radius table

| Event | Lost | Safe | Recovery |
|---|---|---|---|
| Server rooted (e.g. SuperBro) | that host only | all private keys (they never live on servers), other hosts | contained by D8; rebuild; rotate its outbound agent key |
| Workstation infected (MonsterBro WSL) | its host key + agent key | Mac key, git keys, other identities | delete its lines in server `authorized_keys`, regenerate |
| CloudBro (orchestrator) compromised | agent credentials to LinuxBro/SuperBro maintenance | human identity, Mac, mobile | delete agent section + `tag:orchestrator` grants; rebuild box |
| Agent process rogue | its agent key only | human keys, other agents | delete one `authorized_keys` line |
| Phone lost | tailnet access from that phone | keys (none on phone), servers | Tailscale admin: remove device; check-mode re-auth limits stale sessions |

### Why no shared "secret code"

Anything an agent can read, malware on the same host can read; shared across machines, one leak compromises all. Substitute: **identity** (per-host keys, untagged user devices for humans), **policy** (ACL matrix above), **expiry** (check mode now, SSH certificates later if needed).

### Known trade-offs accepted

- Port 27789 = hygiene, not security.
- Web UIs by `ip:port` from mobile = acceptable now; HTTP not HTTPS until Tailscale Serve track.
- Tailscale client is an unstable build on the Mac — revisit before relying on Tailscale SSH in anger.

## 4. Execution phases

Approved execution order: **1 → 2 → 5 → 3 → 4 → 6** (recovery path before closing SuperBro's public door).

### Phase 1 — Registry
1. `config/fleet-hosts.conf`: add CloudBro (`100.100.1.11|27789|christian|cloudbro|allowed|ssh|orchestrator`), add `role` column, MonsterBro Windows as pilot entry.
2. Adjust `scripts/install/ssh-superbro.sh` parsing for new columns.
Accept: `./stow.sh plan macos` clean; script re-runs idempotent.

### Phase 2 — SSH config cleanup (Mac first)
1. One block per destination via `ssh-superbro.sh`: Tailscale IP, port 27789, single explicit `IdentityFile`.
2. Delete `Host *` grab-bag and all duplicate blocks (`superbro` public variant, dup `monsterbro`/`linuxbro`).
3. Test: `ssh -o BatchMode=yes <alias> true` for every alias.
Accept: every alias connects with exactly one key (`ssh -v` shows one offering).

### Phase 3 — Key migration + SuperBro lockout
1. Generate per-source keys per inventory table; agent keys separately.
2. Append publics to each server `authorized_keys` with `from="<source-tailnet-ip>"`; agent keys in a marked section, `agent@` user on servers (D7).
3. **SuperBro order:** verify Mac's new key works via tailnet → enable Tailscale SSH (Phase 5 if not done) → only then close public :22 and remove the public-IP config block.
4. Remove old/legacy key lines (incl. `github` key authorized on SuperBro); delete orphaned private keys locally after verify.
Accept: no lockout (Tailscale SSH + console access as backstops); old keys rejected.

### Phase 4 — Tailscale ACLs
1. Draft policy per matrix in section 2, with `tests` assertions.
2. Apply incrementally: pilots→servers first, then orchestrator, then deny server→everything; probe after each step.
Accept: dashboard probes match the matrix; automation (fleet-update, dockhand, Paseo over SSH) still green.

### Phase 5 — Tailscale SSH recovery (runs before Phase 3 lockout step)
1. `RunSSH=true` on LinuxBro, SuperBro, CloudBro (MonsterBro WSL optional).
2. Policy: `autogroup:member` → `tag:server`, `check` mode, nonroot + root.
3. Verify from Mac and from iPhone (Tailscale app SSH).
Accept: SSH into each server with zero `authorized_keys` dependency — the break-glass test.

### Phase 6 — Dashboard
1. Small script reads `fleet-hosts.conf`; per ordered pair runs `tailscale ping` (direct/relayed + latency) and TCP-connects the fleet SSH port.
2. Regenerates a static self-contained HTML (SVG graph, green/red arrows, latency labels, table fallback) in the `infra/infra.html` tradition.
3. Run after each ACL change; graph must visually match policy.
Accept: `docs/tailnet-access-plan.html` pattern reproduced with live data; no daemon, no deps.

## 5. Later / optional track

- Tailscale Serve for HTTPS + MagicDNS names on web UIs (replaces `ip:port`).
- Short-lived SSH certificates for agents if static agent keys feel too durable.
- Tailscale SSH session recording for full audit.
- Fold `higgins-writer` into agent-key model.
- Stabilize Tailscale client version on Mac.

## 6. Verification checklist (per phase gate)

- [ ] `bash -n` on touched shell files; parse any touched JSON/YAML.
- [ ] Every alias `ssh -o BatchMode=yes <alias> true` passes post-change.
- [ ] Every managed link still resolves inside `~/dotfiles/stow/` (dotfiles rule).
- [ ] `tailscale status` from Mac shows all five hosts; dashboard probes green where matrix says green.
- [ ] Rollback noted per phase (git revert dotfiles; ACL policy re-edited in console; keys kept until N+1 verified).

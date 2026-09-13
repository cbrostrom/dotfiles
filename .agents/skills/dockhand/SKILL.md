---
name: dockhand
description: >-
  Operate Docker stacks via Dockhand MCP on LinuxBro or SuperBro. Load when
  dockhand is mentioned together with linuxbro or superbro — redeploy, restart,
  compose edits, Traefik/infrastructure, stack env. Triggers: dockhand linuxbro,
  dockhand superbro, redeploy stack, mcp-dockhand, docker.superbro.dk,
  docker-lab.
---

# Dockhand stack operations (LinuxBro + SuperBro)

**Load this skill when the task involves Dockhand AND a specific host (`linuxbro` or `superbro`).**

**Default:** use Dockhand MCP via mcporter — not raw SSH `docker compose`.

Do not add dockhand to native Cursor/Pi MCP exposure (tool-restraint). Enable per-host in mcporter only.

## Host routing

| Host | MCP server (mcporter) | Tailscale endpoint | UI (if used) | Compose mirror |
|---|---|---|---|---|
| **LinuxBro** | `dockhand-linuxbro` | `http://100.100.1.100:8092/mcp` | `docker-lab.superbro.dk` (tailnet) | `~/.config/superbro-compose/linuxbro/` |
| **SuperBro** | `dockhand-superbro` | `http://100.100.1.50:8080/mcp` | `docker.superbro.dk` (public) | `~/.config/superbro-compose/superbro/` |

Pick the server matching the host in the user's message. If both hosts are in scope, call `list_environments` on each server separately — IDs are not portable.

**LinuxBro:** `environmentId: 1` (`LinuxBro`).

**SuperBro:** often offline; confirm mcporter connects before planning work.

## MCP tool patterns (both hosts)

| Goal | Tool |
|---|---|
| List stacks | `list_stacks` `{ environmentId }` |
| Read compose | `get_stack_compose` |
| Save + redeploy | `update_stack_compose` `{ ..., restart: true }` |
| Redeploy | `deploy_stack` / `restart_stack` |
| Restart one container | `restart_container` |
| Container file edit | `get_container_file_content` / `write_container_file_content` |
| Logs | `get_container_logs` |
| Host file under compose-repo | `get_system_file_content` (paths under `/app/data/compose-repo/...` only) |

**First adopt quirk:** after `adopt_stack`, API deploy fails until one manual Deploy via Dockhand UI — then MCP deploy works.

## LinuxBro specifics

### Paths

| What | Live path | Mirror |
|---|---|---|
| Compose stacks | `/home/christian/.config/appdata/dockhand/compose-repo/linuxbro/<stack>/` | `~/.config/superbro-compose/linuxbro/<stack>/` |
| Traefik static/dynamic | `/home/christian/.cloudbro/setup/traefik/` | Not fully mirrored — use Traefik container file tools |

Stack name = folder name (`infrastructure`, `media-core`, `immich`, …).

Live `infrastructure` deploy uses **`stack.env`** + **Dockhand stack-variables** (secrets). Never commit secrets to git.

### Redeploy methods

1. **Git push → repo-sync** (routine): edit mirror → push `master` → hourly auto-redeploy per changed stack. Excluded: `_tooling/repo-sync`, `_tooling/dockhand-mcp`. **`infrastructure` is included.**
2. **Dockhand MCP** (immediate): `update_stack_compose` / `deploy_stack` / `restart_stack`.
3. **Container restart** (Traefik plugin/static): `restart_container` on `traefik`.

See `linuxbro/_tooling/repo-sync/README.md` in superbro-compose.

### `infrastructure` (Traefik, cloudflared, uptime-kuma) — highest risk

- **`CF_DNS_API_TOKEN`** must live in Dockhand stack-variables — required for Let's Encrypt DNS-01 renewal. Empty on recreate → cert renewal breaks.
- **`CF_API_EMAIL`** — legacy Cloudflare provider field; **not required** when using API token auth only. Safe to leave unset.
- **`TRAEFIK_AUTH_USER` / `TRAEFIK_AUTH_PASS`** — **removed** (2026-09-11). Dashboard auth is Tinyauth (`tinyauth@docker` on `traefik-lab.superbro.dk`). Do not re-add basicauth.
- Static `traefik.yml` (plugins): full container restart required — file watch does not load plugins.
- Dynamic `dynamic/*.yml`: do not trust hot-reload; restart Traefik after edits.
- Traefik host paths are **not** visible to `get_system_file_content` — use container paths `/etc/traefik/...`.

### Public tunnel routes (linuxbro)

Services on `tunnel-public-chain`, `tunnel-chain`, or `immich-chain` need `cloudflarewarp@file` first. Hostnames: `home`, `plex`, `immich`, `vault` on `*.superbro.dk`.

## SuperBro specifics

- Compose live path: `/home/christian/.config/dockhand/compose-repo/superbro/<stack>/`
- Traefik is a separate stack under `superbro/traefik/` (not bundled in one `infrastructure` stack like linuxbro).
- Dockhand + MCP under `superbro/_tooling/dockhand/`
- Host often inactive — treat as secondary until user confirms it's up.

## Mandatory post-deploy verification (both hosts)

After every deploy or redeploy:

1. **Stuck containers:** full-host sweep for `Created` state — `list_containers` or `docker ps -a | grep -i created`. Start anything stuck. Deploy `success: true` is not proof (known Dockhand bug).
2. **Traefik** (if touched): healthy; no plugin errors in logs.
3. **Routes** (if touched): curl public or tailnet URL as appropriate.
4. **Secrets** (linuxbro `infrastructure` only): confirm `CF_DNS_API_TOKEN` non-empty in container env after recreate.

## Never do this

- SSH `docker compose up` without `-p <stack>` and correct env file.
- Redeploy linuxbro `infrastructure` without secrets in Dockhand stack-variables.
- Force-recreate Traefik with empty `traefik.yml` bind path (auto-vivifies as directory → crash).
- Redeploy `_tooling/dockhand-mcp` from automation that depends on Dockhand staying up.
- Use `deploy_git_stack` on linuxbro unless `list_git_stacks` shows git stacks (today: internal stacks only).

## Related docs

| Doc | Location |
|---|---|
| Compose repo rules | `~/.config/superbro-compose/AGENTS.md` |
| repo-sync (linuxbro) | `~/.config/superbro-compose/linuxbro/_tooling/repo-sync/README.md` |
| Fleet / MCP endpoints | `~/dotfiles/infra/fleet.md` |
| Deploy gotchas | Higgins `projects/dotfiles/gotchas.md` |

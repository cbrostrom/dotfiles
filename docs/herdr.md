# Herdr fleet setup

Herdr is the agent workspace manager across the fleet: TUI on the Mac and WSL,
headless server sessions on linuxbro and cloudbro, machines wired together over
Tailscale via saved SSH profiles. Pi runs inside herdr panes; herdr's native pi
integration (`HERDR_INTEGRATION_ID=pi`, the `herdr-agent-state` extension) feeds
pane lifecycle state, and saved machines let both the TUI and plain CLI (`herdr
--machine <label> …`) drive remote agents without an attached client.

## Layout (mirrors the paseo pattern)

| Path | Owns |
|---|---|
| `sources/herdr/plugins.json` | Canonical plugin registry: repo, ref pin, role matrix, orphans |
| `sources/herdr/config.base.toml` | Base config.toml seeded on hosts with none |
| `setup/herdr.sh` | Install binary, seed config, sync/rollback plugins per profile |
| `zsh/09-herdr.zsh` | Autostart guard, pane-label hooks, machine + pi preset helpers |

Herdr runtime state (`~/.config/herdr/`, plugin checkouts, sockets) is never
stowed; `config.toml` is player-piano territory after seeding so plugin-managed
blocks (Radar) keep working.

## Plugin matrix

| Plugin | Mac (attached) | WSL (attached) | linuxbro/cloudbro (headless) | Ref |
|---|---|---|---|---|
| hhdebb/herdr-radar | x | x | - | pinned |
| kryptamine/herdr-auto-title | x | x | x | pinned |
| ntindle/herdr-resurrect | x | x | x | pinned |
| cloudmanic/herdr-plus | x | x | x | pinned |
| speardragon/herdr-plugin-manager | x | x | - | pinned |
| persiyanov/herdr-reviewr | x | x | x | pinned |
| senna-lang/herdr-agent-usage | x | x | x | pinned |

Mobile companions (Collie, Heeler) are parked: both are removed until the
device story is proven beyond the Mac. Either can be reinstated by moving its
entry back into the plugins list — Heeler `ZingerLittleBee/Heeler/plugin`
(iOS/iPadOS app: console + composer + E2E push) or Collie `AltanS/collie`
(web UI over Tailscale, monitor + reply + push). No PWA plans on either side,
so pick exactly one when mobile matters again.

`ragamo/herdr-flock` (Flock) is an orphan everywhere: fun pixel-art pane, but
its cargo build dependency is not worth the pane.

Add new plugins to `sources/herdr/plugins.json` after reading the repo's
`herdr-plugin.toml` (every build/startup/action command runs locally). Leave
`id: null`; after the first sync copy the id `herdr plugin list --json` reports
back into the manifest, and pin the installed revision (`--ref`) once you have
reviewed it.

## Commands

```sh
./setup/herdr.sh                # apply for this machine's profile
./setup/herdr.sh cloudbro       # apply for another profile explicitly
HERDR_FORCE_SYNC=1 ./setup/herdr.sh   # force reinstall on drift
```

Device wiring (interactive; each asks for SSH auth in your terminal):

```sh
herdmadd linuxbro               # prints the `herdr machine add …` command
herdr machine add 'christian@100.100.1.100:27789' --label linuxbro
herdr machine status linuxbro
```

Everyday use from any pane:

```sh
herdmls                         # list saved machines
herdm linuxbro agent list       # drive remote agents without opening the TUI
herdremote linuxbro             # thin-client attach to the remote session
hsplit down                     # split the calling pane
hnew work                       # new workspace
pigo / piheavy / piarch / pijanitor / pidetective   # pi + Go model/thinking presets
```

Model/thinking switching mid-session stays inside pi (`/preset`, or pick from
the model list); the presets only set the starting point of a pane.

## Paseo coexistence

Paseo is no longer part of the default install path. `WITH_PASEO=1 ./install.sh`
still runs `setup/paseo.sh`; by default the paseo sync line is skipped with a
notice on fresh installs. Nothing is deleted: the paseo daemon, config, and
plugins remain in place until herdr parity (chat via Collie + panes, calls via
`herdr --machine` CLI, monitoring via Radar/Collie) is confirmed.

## Status check

```sh
herdr status server             # local server up?
herdr plugin list               # what quarter of the plugin zoo is loaded
herdr machine status            # fleet profiles healthy?
herdr config check              # config validate
```

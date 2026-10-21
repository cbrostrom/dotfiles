# Stow packages

This directory contains only files that GNU Stow can deploy declaratively into
`$HOME`. Package contents mirror their destination paths.

| Package | Owns |
|---|---|
| `zsh` | Zsh entrypoints and tmux config |
| `git` | Git config, global ignores, and hooks |
| `cli` | Small CLI configs and commands |
| `agents` | Shared agent policy and skills |
| `pi` | Pi config, extensions, hooks, prompts, and shim |
| `desktop` | Cross-platform desktop config |
| `zed` | Zed keymap, tasks, rules, snippets, and themes |
| `macos` | macOS-only config |
| `linux` | Linux-only config |

Preview before applying:

```sh
./stow.sh plan macos
```

Apply or remove a profile:

```sh
./stow.sh apply macos
./stow.sh remove macos
```

Use an isolated target for testing:

```sh
STOW_TARGET="$(mktemp -d)" ./stow.sh apply macos
```

The `cloudbro` profile deliberately excludes GUI packages and standalone
OpenCode. OpenCode Go models are configured inside Pi's model policy and do not
require an OpenCode home directory.

Paseo is not a Stow package. Its home directory mixes stable configuration
with runtime state, plugin checkouts, sockets, logs, keys, and other machine
data. Tracked inputs live under `sources/paseo/`; `setup/paseo.sh` manages the
runtime directory explicitly (opt-in via `WITH_PASEO=1`; herdr is the default
agent workspace — see `docs/herdr.md` and `sources/herdr/`). Herdr follows the
same split: `sources/herdr/` holds the plugin registry and base config;
`setup/herdr.sh` provisions the runtime per host profile.

Stow owns links only. Package installation, generated settings, OS defaults,
and cross-filesystem copies remain explicit setup tasks outside this directory.

# Dotfiles

Declarative home configuration with GNU Stow, plus a small setup layer for
stateful operations that cannot be symlinked safely.

## Layout

```text
~/dotfiles/
├── stow/                 # packages that mirror paths under $HOME
│   ├── zsh/
│   ├── git/
│   ├── cli/
│   ├── agents/
│   ├── cursor/
│   ├── pi/
│   ├── zed/
│   ├── desktop/
│   ├── macos/
│   └── linux/
├── profiles/*.stow       # explicit package lists per machine class
├── setup/                # generated settings and external side effects
├── sources/              # tracked inputs used by setup scripts
├── scripts/              # standalone maintenance and provisioning tools
├── stow.sh               # plan, apply, or remove links
└── install.sh            # apply links and configure mutable app state
```

The rule is strict: **Stow owns links; setup scripts own effects.** Runtime
state, credentials, caches, logs, authentication, and machine-local overrides
are never Stowed.

## Install

Install GNU Stow, clone the repository as `~/dotfiles`, then choose a profile:

```sh
./stow.sh plan macos
./install.sh macos
```

CloudBro uses the minimal Linux development profile with a local standalone
Paseo daemon:

```sh
npm install -g @getpaseo/cli
./stow.sh plan cloudbro
./install.sh cloudbro
```

`cloudbro` installs `zsh`, `git`, `cli`, `agents`, `pi`, and `linux`, then
configures Paseo to launch the local Pi provider. Paseo starts on loopback with
the relay disabled; pair or expose it separately after reviewing the desired
connection boundary. It excludes GUI configuration and standalone OpenCode.
OpenCode Go remains available only through Pi's model policy. CloudBro must not receive a plaintext Higgins vault; it may hold only encrypted
backup data and should reach the canonical writer through its configured remote
boundary.

## Profiles

| Profile | Purpose |
|---|---|
| `macos` | Full local workstation |
| `linux` | Interactive Linux workstation |
| `wsl` | WSL with Windows-side editor copies |
| `server` | Minimal shell and shared agent policy |
| `cloudbro` | Lean Linux development box with Paseo and Pi |

Profile files are plain package lists under `profiles/`. There is no dependency
resolver or module registry.

## Commands

```sh
./stow.sh plan macos       # preview link changes
./stow.sh apply macos      # apply or refresh links
./stow.sh remove macos     # remove links owned by the profile
./install.sh macos         # apply links and configure mutable app settings
./install.sh cloudbro      # apply links and configure local Paseo + Pi
./setup/paseo.sh           # explicitly sync/register Paseo plugins
```

`bootstrap.sh` remains as a compatibility alias for `install.sh`.

## Machine provisioning

Stow does not install software. On macOS, packages remain declared in
`Brewfile`. Linux package lists and focused installers remain under
`scripts/install/`. OS defaults remain under `macos/`.

## Safety

- Never run `stow --adopt` against a real home directory.
- Always run `./stow.sh plan <profile>` before applying.
- Existing regular files are conflicts and are left untouched.
- `~/.pi/agent/settings.json`, `~/.paseo`, secrets, and authentication files are
  runtime-owned and are not linked.

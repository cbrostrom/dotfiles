---
name: dotfiles
description: "Architecture and implementation knowledge for ~/dotfiles. Use when tracing Stow packages, setup scripts, profile selection, hooks, skill routing, or Higgins integration. Read before editing setup, hooks, skills, or symlink ownership."
---

# Dotfiles

The repository separates declarative home files from imperative machine setup.

## Ownership

- `stow/<package>/` mirrors paths under `$HOME`; GNU Stow exclusively owns these links.
- `profiles/*.stow` lists the packages installed on each machine class.
- `setup/` contains explicit operations that cannot be represented as links.
- `sources/` contains tracked source material consumed by setup scripts, not files linked into HOME.
- Runtime state, credentials, caches, logs, auth files, and machine-local overrides stay outside the repository.

## Commands

```sh
./stow.sh plan macos
./stow.sh apply macos
./stow.sh remove macos
./install.sh cloudbro
```

`bootstrap.sh` is only a compatibility alias for `install.sh`.

## Profiles

- `macos`: full local workstation.
- `linux`: interactive Linux desktop.
- `wsl`: WSL with Windows-side Cursor/Zed copies handled by setup scripts.
- `server`: minimal shell and agent policy.
- `cloudbro`: Linux development box with Pi, without GUI or standalone OpenCode.

## Special setup

- `setup/pi.sh` merges tracked defaults into mutable `~/.pi/agent/settings.json` and resolves host model policy.
- `setup/cursor.sh` patches mutable Cursor hooks and performs WSL copies.
- `setup/zed.sh` merges mutable Zed settings and performs WSL copies.
- `setup/paseo.sh` installs tracked plugins without linking `~/.paseo` runtime state.
- `scripts/install/rbw.sh` configures rbw and its local secret loader.

## Agent paths

- Shared skills: `stow/agents/.agents/skills/` → `~/.agents/skills/`
- Cursor config: `stow/cursor/.cursor/`
- Pi config: `stow/pi/.pi/`
- Pi runtime settings baseline: `setup/pi/settings.base.json`

## Safety

Before editing:

1. State files touched, intent, break risk, and verification.
2. Get explicit approval.
3. Never use Stow `--adopt` against a real HOME.
4. Preview with `./stow.sh plan <profile>`.
5. Test structural changes with `STOW_TARGET="$(mktemp -d)"` first.

After editing:

1. Run `bash -n` for shell files and parse JSON/YAML touched.
2. Apply and remove every affected profile in an isolated HOME.
3. Verify every managed link resolves inside `~/dotfiles/stow/`.
4. Run changed-scope quality checks; do not hide baseline findings.

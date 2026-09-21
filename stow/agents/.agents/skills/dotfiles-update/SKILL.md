---
name: dotfiles-update
description: "Update the Stow-based dotfiles locally and propagate an explicit profile to another machine."
trigger: /dotfiles
group: productivity
---

# Dotfiles Update

Run from `~/dotfiles`. Never push unless the user explicitly asks.

## Local

```sh
git status --short
git pull --ff-only
./stow.sh plan macos
./install.sh macos
```

Do not pull over local changes. Review Stow conflicts before applying.

## Remote profiles

```sh
./scripts/system/fleet-update.sh --list
./scripts/system/fleet-update.sh                 # all configured targets
./scripts/system/fleet-update.sh --host linuxbro # one target
```

The updater uses key-only SSH, refuses dirty or locally-ahead repositories,
fast-forwards only, previews Stow changes, runs `install.sh`, applies an optional
`setup/hosts/<name>.sh` hook, and finishes with `scripts/doctor.sh`. It continues
after unreachable or failed hosts, writes separate logs under
`~/.local/state/dotfiles/fleet/`, and exits non-zero if any host failed.

Do not bypass a failed stage with reset, stash, force, or an agent-authored
repair. Inspect that host's log and resolve the cause explicitly. Do not install
standalone OpenCode; OpenCode Go is a Pi model provider configured by
`setup/pi/settings.py`.

## Alerts

Failures trigger a local macOS notification. For another channel, point
`DOTFILES_FLEET_NOTIFY_CMD` at an executable. It receives `status`, `summary`,
and `run-directory` arguments. Keep webhook tokens and other credentials outside
the repository.

## Verification

```sh
./stow.sh plan <profile>
./scripts/doctor.sh <profile>
```

A successful simulation must report no conflicts and doctor must report zero
errors. Verify machine-specific services separately because Stow owns links,
not runtime state.

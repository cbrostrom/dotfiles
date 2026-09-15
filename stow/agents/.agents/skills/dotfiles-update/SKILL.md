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
ssh linuxbro 'git -C ~/dotfiles pull --ff-only && ~/dotfiles/install.sh server'
ssh superbro 'git -C ~/dotfiles pull --ff-only && ~/dotfiles/install.sh server'
ssh monsterbro 'git -C ~/dotfiles pull --ff-only && ~/dotfiles/install.sh wsl'
ssh cloudbro 'git -C ~/dotfiles pull --ff-only && ~/dotfiles/install.sh cloudbro'
```

Skip unreachable machines. Do not install standalone OpenCode; OpenCode Go is a
Pi model provider configured by `setup/pi/settings.py`.

## Verification

```sh
./stow.sh plan <profile>
```

A successful simulation must report no conflicts. Verify machine-specific
services separately because Stow owns links, not runtime state.

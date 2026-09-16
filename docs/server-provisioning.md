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
| LinuxBro| `server`  | lean shell, Git, CLI, agent policy |
| SuperBro| `server`  | lean shell, Git, CLI, agent policy |

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

**`GNU Stow is required`** — run `./scripts/install/debian.sh <profile>` first.

**setlocale warnings persist** — the locale line in `/etc/locale.gen` exists
but was not generated; rerun `sudo locale-gen` and re-login.

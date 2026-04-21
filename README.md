# Dotfiles

Cross-platform dotfiles for macOS, Linux (Debian/Ubuntu), and WSL2.

## Structure

```
.config/dotfiles/
├── .zshrc, .gitconfig, .gitignore_global   # Core dotfiles
├── install.sh, uninstall.sh, dotfiles.sh   # Setup scripts
├── zsh/                                    # Modular zsh config (00-05)
├── .config/                                # bat, cursor, lazygit, procs, starship
├── macos/ghostty/                          # Ghostty terminal (macOS)
├── linux/ghostty/                           # Ghostty terminal (native Linux)
├── linux/install-linux.sh                  # Linux-specific setup
├── wsl/windows-terminal/                    # Windows Terminal settings (WSL)
├── gaming/                                 # Steam gamelaunch, MangoHud, DXVK configs
├── scripts/cursor/                         # Cursor sync scripts
├── utils/                                  # Helper scripts (beets, ssh-agent, etc.)
├── vivaldi/phi/                            # Vivaldi browser theme
└── .local-config.example                   # Machine-specific config template
```

## Installation

```bash
cd ~/.config/dotfiles  # or clone to your preferred location
./install.sh           # Interactive menu, or:
./install.sh --full    # Full setup
./install.sh --minimal # Dotfiles only, skip dependencies
```

## Usage

- `dotfiles` – Interactive menu (requires fzf or whiptail)
- `./install.sh --update` – Refresh symlinks after git pull
- `./install.sh --cursor` – Cursor settings sync only
- `./install.sh --gaming` – Gaming launcher only
- `./status.sh` – Check installation status
- `./uninstall.sh` – Remove symlinks, restore backups

## Platforms

| Platform | Terminal | Notes |
|----------|----------|-------|
| **WSL** | Windows Terminal | Ghostty skipped; settings in wsl/windows-terminal/ |
| **macOS** | Ghostty | Config in macos/ghostty/ |
| **Linux** | Ghostty | Config in linux/ghostty/; Debian/Ubuntu (apt) |

## Key Components

- **zsh** – Modular config with zinit, starship, fzf, zoxide
- **fnm** – Node.js version manager (replaces nvm)
- **Cursor** – Settings/keybindings synced via scripts/cursor/
- **Gaming** – Optional. gamelaunch script for Steam (prompted on install; skipped on WSL)
- **.local-config** – Machine-specific (git-ignored); copy from .local-config.example

## Troubleshooting

### `git config` viser ingen output i terminal

Hvis `lean-ctx` shell-wrapper er aktiv (`lean-ctx-status` viser ON), bliver output fra `git config --list | grep ...` filtreret/munget af wrapperen. Workarounds:

```bash
/opt/homebrew/bin/git config --list   # bypass wrapper
command git config --list             # bypass alias
lean-ctx-off                          # disable wrapper for current shell
```

### SSH commit signing ("cannot run gpg" eller "gpg failed to sign")

`commit.gpgsign=true` med `gpg.format=ssh` — git invoker `ssh-keygen -Y sign` som læser private key direkte og prompter passphrase non-interaktivt → fejler stille → generisk "gpg failed".

Fix: brug **pubkey-filen** som signingkey i stedet for private key. Git bruger så ssh-agent automatisk:

```ini
[user]
    signingkey = ~/.ssh/github.pub   # NOT ~/.ssh/github
[gpg]
    format = ssh
[gpg "ssh"]
    allowedSignersFile = ~/.config/git/allowed_signers
```

Verify med `/opt/homebrew/bin/git log --show-signature -1`.

## Aliases

- `systemupdate` – apt update && upgrade (Debian)
- `gaming-presets` – Edit gamelaunch presets (when gaming is installed)
- `linuxbro-setup` – Setup LinuxBro network symlinks

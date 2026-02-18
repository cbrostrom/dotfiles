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

## Aliases

- `systemupdate` – apt update && upgrade (Debian)
- `gaming-presets` – Edit gamelaunch presets (when gaming is installed)
- `linuxbro-setup` – Setup LinuxBro network symlinks

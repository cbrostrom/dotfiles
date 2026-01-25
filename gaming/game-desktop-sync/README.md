# Game Desktop Sync

Automatically creates `.desktop` files for installed games, making them searchable in GNOME Search.

## Features

- Auto-discovers games from Steam, Lutris, Heroic Launcher
- Uses real game icons from launchers
- Auto-cleanup when games are uninstalled
- Runs automatically via systemd (hourly + on file changes)

## Installation

```bash
cd ~/.config/dotfiles/gaming/game-desktop-sync
./install.sh
```

Then enable and start:

```bash
game-desktop-sync-ctl enable
game-desktop-sync-ctl start
game-desktop-sync-ctl run
```

## Usage

```bash
game-desktop-sync-ctl <command>

Commands:
  start     - Start automatic syncing
  stop      - Stop automatic syncing
  restart   - Restart services
  status    - Show status
  enable    - Enable on boot
  disable   - Disable on boot
  run       - Run sync now
  logs      - Show logs
  clean     - Remove all auto-generated files
  help      - Show help
```

## Uninstallation

```bash
./uninstall.sh
```

## Files

- `game-desktop-sync.sh` - Main sync script
- `game-desktop-sync-ctl` - Control script
- `game-desktop-sync.service` - Systemd service
- `game-desktop-sync.timer` - Hourly timer
- `game-desktop-sync.path` - File watcher
- `install.sh` - Installation script
- `uninstall.sh` - Uninstallation script

## Supported Launchers

- Steam (native & Flatpak)
- Lutris
- Heroic Launcher (Epic & GOG)
- Bottles (experimental)

## Desktop Files Location

Auto-generated files: `~/.local/share/applications/games-auto/`

## Logs

- Systemd: `journalctl --user -u game-desktop-sync.service`
- Script: `~/.local/share/game-desktop-sync.log`

# Scripts Directory

Utility scripts organized by function.

## Cursor Scripts

Located in `cursor/` - manages Cursor IDE settings and extensions:

| Script | Purpose |
|--------|---------|
| `setup-cursor-sync.sh` | Setup symlinks for Cursor settings/keybindings/extensions |
| `backup-cursor-settings.sh` | Create timestamped backup of Cursor settings |
| `install-cursor-extensions.sh` | Install all extensions from extensions.json |
| `update-cursor-extensions.sh` | Update extensions.json with installed extensions |
| `unlink-cursor-extensions.sh` | Remove Cursor symlinks |

**Usage:**
```bash
# Initial setup (run once)
./scripts/cursor/setup-cursor-sync.sh

# Install extensions on new machine
./scripts/cursor/install-cursor-extensions.sh

# After installing new extensions
./scripts/cursor/update-cursor-extensions.sh
```

## Migration Scripts

| Script | Purpose |
|--------|---------|
| `migrate-to-fnm.sh` | Migrate from asdf/nvm to fnm for Node.js |

## Root Scripts (in dotfiles root)

| Script | Purpose |
|--------|---------|
| `install.sh` | Main installer for dotfiles |
| `dotfiles.sh` | Interactive menu system |
| `status.sh` | Check installation status |
| `uninstall.sh` | Remove all dotfiles |
| `backup.sh` | Backup dotfiles before updates |
| `force-update-symlinks.sh` | Force recreate all symlinks |

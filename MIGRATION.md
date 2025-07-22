# Migration Guide: v0.x → v1.0

This guide helps you migrate from the old multi-script system to the new streamlined v1.0 installation.

## What's Changed

### Old System (v0.x)

- Multiple scripts: `dotfiles.sh`, `install-symlinks.sh`, `setup-debian-zsh.sh`, etc.
- Interactive menu system
- Separate scripts for different platforms
- Complex workflow

### New System (v1.0)

- **Single installer**: `./install.sh`
- **Single uninstaller**: `./uninstall.sh`
- **Single status checker**: `./status.sh`
- Cross-platform detection
- Streamlined workflow

## Migration Steps

### 1. Backup Your Current Setup

```bash
# Check current status
./dotfiles.sh status

# Create a backup of your current configuration
cp ~/.zshrc ~/.zshrc.backup
cp ~/.gitconfig ~/.gitconfig.backup
```

### 2. Update Your Repository

```bash
# Pull the latest changes
git pull origin main

# The new scripts are now available
ls -la install.sh uninstall.sh status.sh
```

### 3. Run the New Installer

```bash
# Preview what will be installed
./install.sh --dry-run

# Run the full installation
./install.sh
```

### 4. Verify Installation

```bash
# Check status of all components
./status.sh

# Test your new setup
source ~/.zshrc
```

## Script Mapping

| Old Script                     | New Equivalent             | Notes                    |
| ------------------------------ | -------------------------- | ------------------------ |
| `./dotfiles.sh install`        | `./install.sh`             | Full installation        |
| `./dotfiles.sh uninstall`      | `./uninstall.sh`           | Remove dotfiles          |
| `./dotfiles.sh status`         | `./status.sh`              | Check status             |
| `./install-symlinks.sh`        | `./install.sh --skip-deps` | Only dotfiles            |
| `./setup-debian-zsh.sh`        | `./install.sh`             | Full setup               |
| `./install-starship-direnv.sh` | `./install.sh`             | Included in full install |

## New Features

### Command Line Options

```bash
# Full installation (default)
./install.sh

# Only install dotfiles (skip dependencies)
./install.sh --skip-deps

# Only install dependencies (skip dotfiles)
./install.sh --skip-dotfiles

# Preview installation
./install.sh --dry-run

# Show help
./install.sh --help
```

### Uninstall Options

```bash
# Remove symlinks and restore backups
./uninstall.sh

# Remove symlinks but keep backups
./uninstall.sh --keep-backups

# Preview uninstallation
./uninstall.sh --dry-run
```

## What's Preserved

- ✅ All your existing dotfiles
- ✅ All your existing configurations
- ✅ All your existing symlinks
- ✅ All your existing tools and dependencies

## What's Improved

- 🚀 **Faster installation**: Single command instead of multiple scripts
- 🔍 **Better detection**: Automatic OS and package manager detection
- 🛡️ **Safer installation**: Better error handling and rollback
- 📊 **Status checking**: Comprehensive status reporting
- 🔧 **Dry-run mode**: Preview changes before applying them

## Troubleshooting

### If the new installer fails

```bash
# Check what's wrong
./status.sh

# Try installing only dependencies
./install.sh --skip-dotfiles

# Try installing only dotfiles
./install.sh --skip-deps
```

### If you want to go back

```bash
# Remove the new installation
./uninstall.sh

# Restore your backup
cp ~/.zshrc.backup ~/.zshrc
cp ~/.gitconfig.backup ~/.gitconfig
```

### If you have issues with the old scripts

The old scripts are still available but deprecated. You can still use them if needed:

```bash
# Old scripts still work
./dotfiles.sh install
./install-symlinks.sh
./setup-debian-zsh.sh
```

## Cleanup (Optional)

After successful migration, you can remove the old scripts:

```bash
# Remove old scripts (optional)
rm dotfiles.sh install-symlinks.sh uninstall-symlinks.sh
rm setup-debian-zsh.sh install-starship-direnv.sh
rm fix-debian-terminal.sh test-cross-platform.sh test-terminal.sh
rm symlink-dir.sh
```

## Support

If you encounter issues during migration:

1. Check the status: `./status.sh`
2. Try dry-run mode: `./install.sh --dry-run`
3. Check the troubleshooting section in README.md
4. Create an issue with the output from `./status.sh`

## Rollback

If you need to rollback to the old system:

```bash
# Uninstall new system
./uninstall.sh

# Restore old scripts (if you removed them)
git checkout HEAD~1 -- dotfiles.sh install-symlinks.sh

# Use old system
./dotfiles.sh install
```

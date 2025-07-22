# Legacy Scripts (v0.x)

This directory contains legacy scripts from the previous dotfiles system (v0.x). These scripts are kept for reference and backward compatibility but are **deprecated** in favor of the new v1.0 system.

## ⚠️ Deprecated Scripts

These scripts are no longer needed with the new v1.0 installation system:

### Installation Scripts

- `install-symlinks.sh` - Old symlink installer (replaced by `install.sh`)
- `uninstall-symlinks.sh` - Old symlink uninstaller (replaced by `uninstall.sh`)
- `setup-debian-zsh.sh` - Old Debian setup (functionality included in `install.sh`)
- `install-starship-direnv.sh` - Old Starship/Direnv installer (included in `install.sh`)

### Utility Scripts

- `fix-debian-terminal.sh` - Terminal fix script (included in `install.sh`)
- `test-cross-platform.sh` - Cross-platform test script (functionality in `status.sh`)
- `test-terminal.sh` - Terminal test script (functionality in `status.sh`)
- `symlink-dir.sh` - Directory symlink utility (functionality in `install.sh`)

### Documentation

- `WSL-SETUP.md` - Old WSL setup documentation (see main README.md)

## 🚀 New v1.0 System

The new system uses these streamlined scripts in the root directory:

- `install.sh` - Complete installation (dependencies + dotfiles)
- `uninstall.sh` - Remove dotfiles and restore backups
- `status.sh` - Check status of all components
- `dotfiles.sh` - Modern menu interface

## Usage

### If you need to use legacy scripts:

```bash
# Navigate to utils directory
cd utils

# Run legacy scripts (not recommended)
./install-symlinks.sh
./setup-debian-zsh.sh
```

### Recommended approach:

```bash
# Use the new v1.0 system
cd ~/dotfiles
./install.sh
# or
dotfiles install
```

## Migration

If you're still using these legacy scripts, please migrate to the new v1.0 system:

1. See `../MIGRATION.md` for detailed migration instructions
2. Use `dotfiles install` instead of the old scripts
3. Use `dotfiles status` to check your installation
4. Use `dotfiles update` to keep your dotfiles current

## Cleanup

After successful migration, you can safely remove this directory:

```bash
rm -rf utils/
```

The new v1.0 system provides all the functionality of these legacy scripts in a more streamlined and maintainable way.

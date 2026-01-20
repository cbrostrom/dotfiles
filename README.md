# Dotfiles v3.0 (Optimized & Modular)

A streamlined, cross-platform dotfiles setup for macOS, Linux, and WSL2. Everything you need in one command.

**New in v3.0:**
- 🎯 **Modular Configuration**: .zshrc split into 5 focused modules
- ⚡ **Performance Optimized**: Lazy loading, completion caching, consolidated FZF
- 🧹 **Simplified**: Removed asdf and Rust builds (using package managers instead)
- 💾 **Backup System**: New backup.sh for safe updates
- 🔐 **Better Security**: .local-secrets support built-in
- 🖥️ **Platform-Specific**: Separate configs for Linux (Hyprland) and macOS
- 📝 **Local Config Tracking**: .local-config tracks installed components per machine

## 📁 Structure

```
~/dotfiles/
├── zsh/                  # Cross-platform shell config (modular)
├── .config/              # Cross-platform configs only
│   ├── starship.toml
│   └── lsd/
│
├── linux/                # Linux-specific (Hyprland, Waybar)
│   ├── hyprland/
│   ├── waybar/
│   ├── interception/
│   └── install-hyprland.sh
│
├── macos/                # macOS-specific (Ghostty, etc.)
│   └── ghostty/
│
├── .local-config         # Machine-specific settings (git-ignored)
├── install.sh            # Main cross-platform installer
└── ...
```

## 🚀 Quick Start

```bash
# Clone the repository
git clone <your-repo-url> ~/dotfiles
cd ~/dotfiles

# Install everything
./install.sh

# Or install with verification
./install.sh --verify
```

That's it! The installer will:

- Detect your OS automatically
- Install all dependencies (zsh, git, Node.js via fnm)
- Setup modern CLI tools (starship, lsd, bat, ripgrep, fzf, etc.)
- Configure your shell with optimized plugins
- Create symlinks for all dotfiles
- Set zsh as your default shell
- Install fnm for Node.js with .nvmrc support
- Create .local-config to track installed components
- Verify the installation (with `--verify` flag)

## 🖥️ Platform-Specific Setup

### Linux (GNOME)

Linux-specific configurations are automatically set up during installation.

For GNOME-specific setup (optional):

```bash
cd ~/dotfiles/linux/gnome
./install-gnome-tools.sh
```

This installs:
- GNOME Tweaks and extensions
- dconf settings backup/restore scripts
- GNOME Shell customization tools
- Recommended extensions list

The installer automatically detects your desktop environment and offers GNOME-specific setup if you're running GNOME.

See [linux/README.md](linux/README.md) for details.

### macOS

Ghostty and other macOS-specific configs are in `macos/` and automatically symlinked during installation.

## 📝 Local Configuration

Your machine-specific settings are tracked in `.local-config`:

```bash
# View your current setup
cat ~/dotfiles/.local-config
```

This file tracks:
- Platform (linux/macos/wsl)
- Desktop environment (hyprland/gnome/kde)
- Installed optional components
- Machine identifier
- Hardware specs (for AI assistants)

## 🔧 Troubleshooting

If you encounter zsh prompt issues on Debian/Ubuntu systems:

```bash
# Check current status
./fix-zsh.sh status

# Fix zsh prompt issues
./fix-zsh.sh fix

# Or run the full installer with verification
./install.sh --verify
```

If you encounter direnv issues (especially on WSL):

```bash
# Fix direnv issues
./fix-direnv.sh

# Or run the full installer with verification
./install.sh --verify
```

If you have missing tools after installation:

```bash
# Run the full installer again (automatically checks for missing tools)
./install.sh --verify
```

## 🎯 Using the Menu System

After installation, you can use the interactive menu from anywhere:

```bash
# Show the menu (uses fzf by default, whiptail as fallback)
./dotfiles.sh

# Or run specific commands directly
./install.sh --verify
./status.sh
./uninstall.sh
```

**Requirements for the menu system:**

- `fzf` (automatically installed via `install.sh`, preferred)
- `whiptail` (fallback, usually pre-installed on most systems)
- On Debian/Ubuntu: `sudo apt install fzf`
- On macOS: `brew install fzf`

**FZF Features:**

- Fuzzy search (type to filter)
- Preview windows
- Cross-platform compatibility

The menu provides these options:

1. **Full installation** - Install everything with verification
2. **Install dotfiles only** - Only install dotfiles (skip dependencies)
3. **Install dependencies only** - Only install dependencies (skip dotfiles)
4. **Full installation + system update** - Install everything + update system packages
5. **Uninstall dotfiles** - Remove all dotfiles and configurations
6. **Check status** - Show status of all components
7. **Update dotfiles** - Pull latest changes from git
8. **Preview installation** - Show what would be installed (dry run)
9. **Show help** - Show help message
10. **Reload shell configuration** - Reload zsh configuration
11. **Force update symlinks** - Force recreation of all symlinks
12. **Exit** - Exit the menu

## 📚 Documentation

- **[Migration Guide](docs/MIGRATION.md)** - Migrating from v0.x to v2.0
- **[ASDF Migration](docs/ASDF-MIGRATION.md)** - Complete asdf and asdf-direnv guide
- **[Changelog](docs/CHANGELOG.md)** - Version history and changes
- **[Summary](docs/SUMMARY.md)** - Complete v2.0 system overview

## 🛠️ What's Included

### Core Tools

- **zsh** with zinit plugin manager
- **starship** prompt (cross-platform)
- **lsd** (modern ls replacement)
- **bat** (modern cat replacement)
- **ripgrep** (fast grep replacement)
- **fd-find** (modern find replacement)
- **fzf** (fuzzy finder with visual completion)
- **direnv** (environment switching)

### System Tools

- **procs** (modern ps replacement)
- **bottom** (modern top replacement)
- **zoxide** (smart cd replacement)
- **du-dust** (modern du replacement)
- **tealdeer** (tldr replacement)
- **sd** (modern sed replacement)

### Git Tools

- **git-delta** (enhanced git diff)
- **lazygit** (git TUI)
- **git-fuzzy** (git fuzzy finder)
- **ripgrep-all** (search in all files)

### Development Tools

- **Node.js** via asdf
- **Python** via asdf
- **Go** programming language via asdf
- **Rust** programming language via asdf
- **asdf** version manager with asdf-direnv
- **git** with enhanced configuration

### Platform-Specific Features

- **macOS**: Ghostty terminal config, Homebrew integration, Cursor settings sync
- **Linux**: xterm-256color terminal fix, apt/yum/dnf support, Cursor settings sync
- **WSL2**: Windows Terminal integration

## 🎨 Features

### Cross-Platform Compatibility

- Automatic OS detection
- Platform-specific package managers
- Relative symlinks for portability
- Terminal compatibility fixes
- Enhanced dependency management

### Development Environment

- Modern shell with plugins
- Fast fuzzy finding with fzf
- Enhanced git workflow
- Project-specific environments with direnv
- Multiple language support (Node.js, Go, Rust)

### Terminal Experience

- Beautiful prompt with starship
- Syntax highlighting
- Auto-completion with visual interface
- History search
- Git integration

## 🔧 Installation Options

```bash
# Full installation with verification
./install.sh --verify

# Install only dependencies (skip dotfiles)
./install.sh --skip-dotfiles

# Install only dotfiles (skip dependencies)
./install.sh --skip-deps

# Preview what would be installed
./install.sh --dry-run

# Interactive menu (uses fzf with whiptail fallback)
./dotfiles.sh

# Fix zsh prompt issues specifically
./fix-zsh.sh fix

# Check zsh status
./fix-zsh.sh status

# Setup Cursor settings sync (included in install.sh)
./setup-cursor-sync.sh
```

## 🆕 What's New in v2.0

### Enhanced Installation

- **Better dependency management**: More comprehensive package lists for Debian/Ubuntu
- **Improved zsh setup**: Proper shell detection and configuration
- **Installation verification**: New `--verify` flag to check setup
- **Enhanced error handling**: Better detection and reporting of issues

### Node.js Management

- **fnm (Fast Node Manager)**: Replaced asdf for Node.js with better .nvmrc support
- **Automatic version switching**: Automatically switches Node.js versions based on .nvmrc files
- **Faster performance**: fnm is significantly faster than nvm and asdf for Node.js
- **Migration support**: Migration script to transition from asdf to fnm

### New Tools

- **fix-zsh.sh**: Dedicated script for fixing zsh prompt issues
- **migrate-to-fnm.sh**: Migration script for transitioning to fnm
- **Status checking**: Better verification of installation components
- **Cross-platform improvements**: Better support for Debian 12 and other Linux distributions

### Bug Fixes

- Fixed zsh prompt issues on Debian systems
- Improved symlink creation with relative paths
- Better package manager detection
- Enhanced terminal configuration

## 🟢 Node.js Management with fnm

Your dotfiles now use **fnm** (Fast Node Manager) for Node.js version management, providing better `.nvmrc` support and faster performance.

### Basic Usage

```bash
# Install latest LTS
fnm install --lts

# Install specific version
fnm install 18.17.0

# Use specific version
fnm use 18.17.0

# Set default version
fnm default 18.17.0

# List installed versions
fnm list
```

**Note**: For compatibility, `nvm` is aliased to `fnm`, so you can use either command:

```bash
nvm install --lts    # Same as fnm install --lts
nvm use 18.17.0      # Same as fnm use 18.17.0
```

### .nvmrc Support

Create a `.nvmrc` file in your project:

```bash
echo "18.17.0" > .nvmrc
```

When you enter the directory, fnm automatically switches to the specified version:

```bash
cd my-project  # Automatically switches to Node.js 18.17.0
node --version # v18.17.0
```

### Migration from asdf

If you're migrating from asdf, use the migration script:

```bash
./migrate-to-fnm.sh
```

For more details, see [docs/FNM-SETUP.md](docs/FNM-SETUP.md).

## 🐛 Common Issues & Solutions

### Zsh Prompt Not Working

```bash
# Check if zsh is properly configured
./fix-zsh.sh status

# Fix zsh prompt issues
./fix-zsh.sh fix

# Or reinstall with verification
./install.sh --verify
```

### Missing Dependencies

```bash
# Install only dependencies
./install.sh --skip-dotfiles

# Check what's missing
./status.sh
```

### Permission Issues

```bash
# Make scripts executable
chmod +x *.sh

# Check file permissions
ls -la *.sh
```

## 🔄 Updating

```bash
# Update dotfiles
git pull origin main

# Reinstall with verification
./install.sh --verify
```

## 🗑️ Uninstalling

```bash
# Remove all dotfiles and configurations
./uninstall.sh
```

## 📋 Requirements

- **macOS**: Homebrew (will be installed if missing)
- **Linux**: apt, yum, or dnf package manager
- **WSL2**: Windows Terminal (optional)

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test on multiple platforms
5. Submit a pull request

## 💻 Cursor Settings Sync

Your Cursor IDE settings (settings.json, keybindings.json, snippets) are automatically synced via dotfiles using symlinks.

### How It Works

The setup creates symlinks from Cursor's User directory to your dotfiles:

```
~/Library/Application Support/Cursor/User/settings.json → ~/dotfiles/.config/cursor/settings.json
~/Library/Application Support/Cursor/User/keybindings.json → ~/dotfiles/.config/cursor/keybindings.json
~/Library/Application Support/Cursor/User/snippets/ → ~/dotfiles/.config/cursor/snippets/
```

**Benefits:**
- ✅ Any changes in Cursor are automatically reflected in dotfiles
- ✅ Commit and push to sync across machines
- ✅ No extensions needed - native symlinks
- ✅ Works on macOS and Linux

### Setup on New Machine

The Cursor sync is automatically included in `./install.sh`, but you can also run it separately:

```bash
# Setup Cursor settings sync
./setup-cursor-sync.sh
```

### Backup Your Settings

Before making changes, create a backup:

```bash
# Create timestamped backup
./backup-cursor-settings.sh

# Backups are saved to ~/.cursor-backups/
```

### Manual Restore

If you need to restore from a backup:

```bash
# List available backups
ls -la ~/.cursor-backups/

# Restore from specific backup
cp -r ~/.cursor-backups/backup_TIMESTAMP/* "$HOME/Library/Application Support/Cursor/User/"
```

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

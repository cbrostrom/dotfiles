# Dotfiles v2.0

A streamlined, cross-platform dotfiles setup for macOS, Linux, and WSL2. Everything you need in one command.

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
- Install all dependencies (zsh, git, Node.js, Go, Rust, etc.)
- Setup development tools (starship, lsd, fzf, direnv, etc.)
- Configure your shell with plugins
- Create symlinks for all dotfiles
- Set zsh as your default shell
- Verify the installation (with `--verify` flag)

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

If you have missing tools after installation:

```bash
# Install only missing tools
./install-missing.sh

# Or run the full installer again
./install.sh --verify
```

## 🎯 Using the Menu System

After installation, you can use the interactive menu from anywhere:

```bash
# Show the menu (uses smenu by default)
./dotfiles.sh

# Or run specific commands directly
./install.sh --verify
./status.sh
./uninstall.sh
```

**Requirements for the menu system:**
- `smenu` package (automatically installed via `install.sh`)
- On Debian/Ubuntu: `sudo apt install smenu`
- On macOS: `brew install smenu`

The menu provides these options:
1. **Full installation** - Install everything with verification
2. **Install dotfiles only** - Only install dotfiles (skip dependencies)
3. **Install dependencies only** - Only install dependencies (skip dotfiles)
4. **Uninstall dotfiles** - Remove all dotfiles and configurations
5. **Check status** - Show status of all components
6. **Update dotfiles** - Pull latest changes from git
7. **Preview installation** - Show what would be installed (dry run)
8. **Show help** - Show help message
9. **Reload shell configuration** - Reload zsh configuration
10. **Force update symlinks** - Force recreation of all symlinks
11. **Install missing tools** - Install only missing tools
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
- **fzf** (fuzzy finder with visual completion)
- **direnv** (environment switching)

### Development Tools

- **Node.js** via asdf
- **Python** via asdf
- **Go** programming language via asdf
- **Rust** programming language via asdf
- **asdf** version manager with asdf-direnv
- **git** with enhanced configuration

### Platform-Specific Features

- **macOS**: Ghostty terminal config, Homebrew integration
- **Linux**: xterm-256color terminal fix, apt/yum/dnf support
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

# Install only missing tools (after partial installation)
./install-missing.sh

# Interactive menu (uses smenu)
./dotfiles.sh

# Fix zsh prompt issues specifically
./fix-zsh.sh fix

# Check zsh status
./fix-zsh.sh status
```

## 🆕 What's New in v2.0

### Enhanced Installation
- **Better dependency management**: More comprehensive package lists for Debian/Ubuntu
- **Improved zsh setup**: Proper shell detection and configuration
- **Installation verification**: New `--verify` flag to check setup
- **Enhanced error handling**: Better detection and reporting of issues

### New Tools
- **fix-zsh.sh**: Dedicated script for fixing zsh prompt issues
- **Status checking**: Better verification of installation components
- **Cross-platform improvements**: Better support for Debian 12 and other Linux distributions

### Bug Fixes
- Fixed zsh prompt issues on Debian systems
- Improved symlink creation with relative paths
- Better package manager detection
- Enhanced terminal configuration

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

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

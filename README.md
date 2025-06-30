# Dotfiles Manager

A simple and powerful dotfiles management system that works across macOS and WSL2 Ubuntu.

## Features

- 🔄 **Cross-platform**: Works on macOS and WSL2 Ubuntu
- ⚡ **Fast**: Simple symlink-based approach
- 🛡️ **Safe**: Automatic backups of existing files
- 📝 **Configurable**: Easy-to-edit configuration file
- 🎯 **Smart**: OS detection and shell-specific setup
- 🚀 **Easy**: One-command installation and setup

## Quick Start

1. **Clone your dotfiles repo** (if you haven't already):
   ```bash
   git clone <your-repo-url> ~/.dotfiles
   cd ~/.dotfiles
   ```

2. **Install the dotfiles manager**:
   ```bash
   chmod +x scripts/install.sh
   ./scripts/install.sh
   ```

3. **Restart your shell** or source your RC file:
   ```bash
   source ~/.zshrc  # or ~/.bashrc
   ```

4. **Install your dotfiles**:
   ```bash
   dotfiles install
   ```

## Usage

### Main Menu (Interactive)
```bash
# Open the complete control center
dotfiles
```

### Quick Commands
```bash
# Dotfiles management
dotfiles install
dotfiles list
dotfiles uninstall
dotfiles init

# Version management
dotfiles version
dotfiles bump patch
dotfiles status
dotfiles quick
dotfiles release

# Utilities
dotfiles help
dotfiles menu
```

### Legacy Commands (Still Available)
```bash
# Direct access to individual managers
dotfiles-version status
dotfiles-version bump patch
dotfiles-version release
```

### Configuration

Edit `dotfiles.conf` to customize which files are linked:

```bash
# Format: source_file:target_location:description
.zshrc:~/.zshrc:Zsh configuration
.gitconfig:~/.gitconfig:Git configuration
.config/nvim/init.vim:~/.config/nvim/init.vim:Neovim configuration
```

### Adding New Dotfiles

1. **Add your file** to the dotfiles repo
2. **Add an entry** to `dotfiles.conf`:
   ```
   .myconfig:~/.myconfig:My custom configuration
   ```
3. **Run** `dotfiles install`

## File Structure

```
~/.dotfiles/
├── scripts/
│   ├── main.sh               # Unified main menu
│   ├── dotfiles.sh           # Dotfiles management
│   ├── version.sh            # Version manager
│   ├── install.sh            # PATH installer
│   └── dotfiles.conf         # Configuration file
├── VERSION                   # Current version
├── .zshrc                    # Your dotfiles
├── .gitconfig
├── .config/
│   ├── zsh/
│   │   ├── aliases
│   │   ├── plugins
│   │   └── env
│   ├── ghostty/
│   │   └── config
│   └── gh/
│       └── config.yml
└── README.md
```

## How It Works

1. **Unified Interface**: Single `dotfiles` command with interactive menu
2. **Symlinks**: Creates symbolic links from your dotfiles repo to your home directory
3. **Backups**: Automatically backs up existing files before creating symlinks
4. **OS Detection**: Detects macOS vs WSL2 Ubuntu and adjusts behavior accordingly
5. **Shell Detection**: Automatically detects your shell (zsh/bash) and updates the correct RC file
6. **Version Management**: Semantic versioning with git integration

## Examples

### Basic Setup
```bash
# Install the manager
./scripts/install.sh

# Open main menu
dotfiles

# Quick commands
dotfiles install
dotfiles list
dotfiles quick
```

### Version Management
```bash
# Quick update
dotfiles quick

# Full release
dotfiles release
```

## Troubleshooting

### "Permission denied" errors
```bash
chmod +x scripts/*.sh
```

### Alias not found
```bash
source ~/.zshrc  # or ~/.bashrc
```

### Wrong symlinks
```bash
dotfiles uninstall
dotfiles install
```

### Backup files
Backup files are created with timestamps:
```bash
ls -la ~/.zshrc.backup.*
```

## Advanced Usage

### Multiple Configurations
Create different config files for different environments:

```bash
# macOS config
dotfiles --config macos.conf install

# WSL config  
dotfiles --config wsl.conf install
```

### Conditional Linking
The script automatically skips files that don't exist in your repo, so you can have one config file for all environments.

### Integration with Other Tools
Works well with:
- [Homebrew](https://brew.sh/) (macOS)
- [apt](https://ubuntu.com/) (Ubuntu/WSL)
- [Git](https://git-scm.com/) for version control

## Contributing

Feel free to submit issues and enhancement requests!

## License

MIT License - feel free to use this however you like.
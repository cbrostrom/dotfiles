# Dotfiles v1.0 - Complete Installation Guide

A streamlined, cross-platform dotfiles setup for macOS, Linux, and WSL2. Everything you need in one command.

## Quick Start

```bash
# Clone the repository
git clone <your-repo-url> ~/dotfiles
cd ~/dotfiles

# Install everything
./install.sh
```

That's it! The installer will:

- Detect your OS automatically
- Install all dependencies (zsh, git, Node.js, Go, Rust, etc.)
- Setup development tools (starship, lsd, fzf, direnv, etc.)
- Configure your shell with plugins
- Create symlinks for all dotfiles
- Set zsh as your default shell

## Using the Menu System

After installation, you can use the interactive menu from anywhere:

```bash
# Show the menu (requires dotfiles alias)
dotfiles

# Or run specific commands
dotfiles install
dotfiles status
dotfiles update
dotfiles uninstall
```

## What's Included

### Core Tools

- **zsh** with zinit plugin manager
- **starship** prompt (cross-platform)
- **lsd** (modern ls replacement)
- **bat** (modern cat replacement)
- **ripgrep** (fast grep replacement)
- **fzf** (fuzzy finder)
- **direnv** (environment switching)

### Development Tools

- **Node.js** via NVM
- **Go** programming language
- **Rust** programming language
- **asdf** version manager
- **git** with enhanced configuration

### Platform-Specific Features

- **macOS**: Ghostty terminal config, Homebrew integration
- **Linux**: xterm-256color terminal fix, apt/yum/dnf support
- **WSL2**: Windows Terminal integration, cross-platform compatibility

## Installation Options

### Direct Script Usage

```bash
# Full installation (default)
./install.sh

# Only install dotfiles (skip dependencies)
./install.sh --skip-deps

# Only install dependencies (skip dotfiles)
./install.sh --skip-dotfiles

# Preview what would be installed
./install.sh --dry-run

# Show help
./install.sh --help
```

### Menu System Usage

```bash
# Interactive menu (recommended)
dotfiles

# Direct commands via menu system
dotfiles install
dotfiles install --skip-deps
dotfiles install --skip-dotfiles
dotfiles uninstall
dotfiles status
dotfiles update
dotfiles dry-run
dotfiles help
```

## Post-Installation

After installation:

1. **Log out and log back in** (or restart your terminal)
2. Your new zsh setup will be active
3. Verify installation:
   ```bash
   starship --version
   lsd --version
   node --version
   go version
   ```

## Troubleshooting

### Common Issues

**Terminal colors not working on Linux:**

- The installer automatically sets `TERM=xterm-256color`
- If issues persist, run: `export TERM=xterm-256color`

**Backspace not working:**

- The installer creates `~/.inputrc` to fix this
- If issues persist, run: `bind -f ~/.inputrc`

**Symlinks not working:**

- Check if the source files exist in the dotfiles directory
- Run `./install.sh --dry-run` to see what would be installed

**Package manager not found:**

- **macOS**: Install Homebrew first: `/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"`
- **Linux**: The installer supports apt, yum, and dnf

### Manual Steps (if needed)

If the installer fails, you can run individual components:

```bash
# Install basic packages
sudo apt-get update && sudo apt-get install -y zsh git curl wget

# Install Rust tools manually
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
source ~/.cargo/env
cargo install starship lsd bat ripgrep fzf

# Install NVM
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash

# Change default shell
chsh -s /bin/zsh
```

## Configuration Files

The installer creates symlinks for these files:

- `~/.zshrc` - Main shell configuration
- `~/.gitconfig` - Git configuration
- `~/.gitignore_global` - Global gitignore
- `~/.config/starship.toml` - Starship prompt config
- `~/.config/lsd/` - lsd configuration
- `~/.config/ghostty/` - Ghostty terminal config (macOS)
- `~/.config/windows-terminal/` - Windows Terminal config (WSL2)

## Updating

To update your dotfiles:

```bash
cd ~/dotfiles
git pull
./install.sh --skip-deps  # Only update dotfiles, skip dependencies
```

## Uninstalling

To remove dotfiles (keeps your data):

```bash
cd ~/dotfiles
# Remove symlinks (keeps backups)
rm ~/.zshrc ~/.gitconfig ~/.gitignore_global
rm -rf ~/.config/lsd ~/.config/starship.toml

# Change shell back to bash (optional)
chsh -s /bin/bash
```

## Features

### Cross-Platform Compatibility

- Automatic OS detection
- Platform-specific package managers
- Relative symlinks for portability
- Terminal compatibility fixes

### Development Environment

- Modern shell with plugins
- Fast fuzzy finding with fzf
- Enhanced git workflow
- Project-specific environments with direnv
- Multiple language support (Node.js, Go, Rust)

### Terminal Experience

- Beautiful prompt with starship
- Syntax highlighting
- Auto-completion
- History search
- Git integration

## Contributing

This is a personal dotfiles setup, but feel free to fork and adapt for your own use.

## License

MIT License - feel free to use and modify as needed.

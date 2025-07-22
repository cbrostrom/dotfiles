# Dotfiles v1.0

A streamlined, cross-platform dotfiles setup for macOS, Linux, and WSL2. Everything you need in one command.

## 🚀 Quick Start

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

## 🎯 Using the Menu System

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

## 📚 Documentation

- **[Migration Guide](docs/MIGRATION.md)** - Migrating from v0.x to v1.0
- **[ASDF Migration](docs/ASDF-MIGRATION.md)** - Complete asdf and asdf-direnv guide
- **[Changelog](docs/CHANGELOG.md)** - Version history and changes
- **[Summary](docs/SUMMARY.md)** - Complete v1.0 system overview

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
```

### Menu System Usage

```bash
# Interactive menu (recommended)
dotfiles

# Direct commands via menu system
dotfiles install
dotfiles install --skip-deps
dotfiles uninstall
dotfiles status
dotfiles update
dotfiles dry-run
```

## 🆘 Troubleshooting

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

## 🔄 Updating

To update your dotfiles:

```bash
cd ~/dotfiles
git pull
./install.sh --skip-deps  # Only update dotfiles, skip dependencies
# or
dotfiles update
```

## 🗑️ Uninstalling

To remove dotfiles (keeps your data):

```bash
cd ~/dotfiles
./uninstall.sh
# or
dotfiles uninstall
```

## 🤝 Contributing

This is a personal dotfiles setup, but feel free to fork and adapt for your own use.

## 📄 License

MIT License - feel free to use and modify as needed.

---

**For detailed documentation, see the [docs/](docs/) folder.**

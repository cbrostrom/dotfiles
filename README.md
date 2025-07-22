# 🚀 Optimized Dotfiles for Web Development 2025

A cross-platform dotfiles setup optimized for modern web development with performance, security, and developer experience in mind.

## ✨ Features

### 🎯 **Performance Optimizations**

- **zsh-defer**: Lazy loading for faster shell startup
- **zinit**: Fast plugin manager with async loading
- **Starship**: Ultra-fast prompt written in Rust with modern formatting
- **Optimized completions**: Smart caching and async loading

### 🛠️ **Modern Tool Stack**

- **lsd**: Modern `ls` replacement with icons and colors
- **bat**: Better `cat` with syntax highlighting
- **ripgrep**: Ultra-fast text search
- **fd**: Fast file finder
- **procs**: Better process listing
- **htop**: Interactive process viewer
- **ncdu**: Disk usage analyzer
- **tldr**: Simplified command help

### 🔍 **Enhanced Search & Navigation**

- **zoxide**: Smarter `cd` with learning
- **fzf**: Fuzzy finder with keybindings
- **atuin**: Better shell history search
- **ripgrep-all**: Search in all file types

### 🎨 **Development Experience**

- **git-delta**: Beautiful git diffs
- **git-fuzzy**: Interactive git operations
- **lazygit**: Terminal UI for git
- **direnv**: Project-specific environment variables
- **asdf**: Multi-language version management

### 🔒 **Security & Monitoring**

- **htop**: System monitoring
- **ncdu**: Disk usage analysis
- **procs**: Process monitoring

## 🚀 Quick Start

### Installation

```bash
# Clone the repository
git clone https://github.com/cbrostrom/dotfiles.git ~/dotfiles
cd ~/dotfiles

# Run the installer (cross-platform compatible)
./install-symlinks.sh

# Or use the main dotfiles script
./dotfiles.sh install

# Restart your shell or source your rc file
source ~/.zshrc
```

### Cross-Platform Support

The installation scripts now work on:

- ✅ **macOS** (zsh/bash)
- ✅ **Linux** (Ubuntu, Debian, CentOS, etc.)
- ✅ **WSL2** (Windows Subsystem for Linux)
- ✅ **Any shell** (zsh, bash, etc.)

The scripts automatically detect your OS and use appropriate tools and fallbacks.

### Testing Compatibility

Before installing, you can test your system's compatibility:

```bash
# Run the compatibility test
./test-cross-platform.sh
```

This will check:

- ✅ Script executability
- ✅ Required tools availability
- ✅ Optional tools for relative paths
- ✅ Script syntax validation
- ✅ Basic functionality

### Usage

```bash
# Main dotfiles management
dotfiles install    # Install all dotfiles
dotfiles list       # Show status
dotfiles update     # Pull and reinstall
dotfiles uninstall  # Remove symlinks

# Version management
dotfiles version    # Show current version
dotfiles bump       # Bump version
dotfiles quick      # Quick update
dotfiles release    # Full release workflow
```

## 🎯 **Optimizations Implemented**

### **Performance**

- ✅ **zsh-defer**: Lazy loading for plugins
- ✅ **zinit**: Fast plugin manager
- ✅ **Starship**: Rust-based prompt with modern formatting
- ✅ **Async completions**: Non-blocking completion loading

### **Modern Tools**

- ✅ **lsd**: Modern ls replacement with icons
- ✅ **bat**: Syntax-highlighted cat
- ✅ **ripgrep**: Fast text search
- ✅ **fd**: Fast file finder
- ✅ **procs**: Better process listing
- ✅ **htop**: System monitoring
- ✅ **ncdu**: Disk usage analysis

### **Development Enhancements**

- ✅ **zoxide**: Smart directory navigation
- ✅ **atuin**: Better history search
- ✅ **direnv**: Project-specific env vars
- ✅ **asdf**: Multi-language version management
- ✅ **fzf keybindings**: Enhanced fuzzy finding

### **Git Improvements**

- ✅ **git-delta**: Beautiful diffs with side-by-side view
- ✅ **git-fuzzy**: Interactive git operations
- ✅ **lazygit**: Terminal UI for git

### **Shell Improvements**

- ✅ **Starship**: Modern, fast prompt with icons and formatting
- ✅ **zsh-autocomplete**: Better completions
- ✅ **zsh-syntax-highlighting**: Syntax highlighting

### **Cross-Platform Tools**

- ✅ **ripgrep-all**: Search in all file types
- ✅ **fd**: Fast file finding
- ✅ **procs**: Better process listing

### **Windows Terminal Support**

- ✅ **Warm Nordic Theme**: Matches Starship prompt colors
- ✅ **Multiple Color Schemes**: Nordic Dark, Dracula, Solarized Dark
- ✅ **WSL Integration**: Proper Ubuntu profile with home directory
- ✅ **SSH Profile Support**: Preserves custom SSH configurations
- ✅ **JuliaMono Font**: Optimized for Nerd Fonts and icons
- ✅ **Acrylic Background**: Modern glass effect
- ✅ **Enhanced Keybindings**: Productivity shortcuts
- ✅ **Auto-Backup**: Safely preserves existing settings

## 🔧 **Configuration Files**

### **Shell Configuration**

- `.zshrc`: Main shell configuration (works with zsh and bash)
- `.config/zsh/aliases`: Command aliases
- `.config/zsh/plugins`: Plugin management
- `.config/zsh/env`: Environment variables

### **Installation Scripts**

- `install-symlinks.sh`: Main cross-platform installer
- `uninstall-symlinks.sh`: Cross-platform uninstaller
- `dotfiles.sh`: Interactive dotfiles manager with menu system
- `symlink-dir.sh`: Recursive directory symlinker
- `test-cross-platform.sh`: Compatibility test script

### **Menu System Features**

The `dotfiles.sh` script now includes an interactive menu with:

- 🎯 **Easy Navigation**: Numbered options for all operations
- 🔧 **Quick Actions**: Install, uninstall, status check
- 📁 **File Management**: Individual .zshrc management
- 🚀 **Full Scripts**: Direct access to install-symlinks.sh and uninstall-symlinks.sh
- 🧪 **Testing**: Cross-platform compatibility testing
- 📖 **Help**: Built-in help system

### **Git Configuration**

- `.gitconfig`: Git settings with delta integration
- `.gitignore_global`: Global gitignore

### **Terminal Configuration**

- `.config/ghostty/config`: Ghostty terminal
- `.config/starship.toml`: Starship prompt with modern formatting
- `.config/windows-terminal/settings.json`: Windows Terminal with Warm Nordic theme

## 🎨 **Key Aliases**

```bash
# File operations
ls='lsd --group-dirs first'
ll='lsd --group-dirs first -l'
la='lsd --group-dirs first -la'
tree='lsd --tree --level=2'
cat='bat'
grep='rg'
find='fd'

# Modern tools
ps='procs'
h='htop'
disk='ncdu'
search='rga'
fuzzy='git-fuzzy'

# Git shortcuts
gs='git status'
ga='git add'
gc='git commit'
gp='git push'
gl='lazygit'

# Package managers
ni='npm install'
nr='npm run'
nd='npm run dev'
pi='pnpm install'
pr='pnpm run'
pd='pnpm run dev'
```

## 🔑 **Keybindings**

- `Ctrl+R`: FZF history search
- `Ctrl+T`: FZF file search
- `Alt+C`: FZF directory search
- `Ctrl+Up/Down`: Smart history search

## 🖥️ **Windows Terminal Features**

### **Profiles**

- **WSL Ubuntu**: Starts in your WSL home directory
- **PowerShell Core**: Modern PowerShell with Warm Nordic theme
- **Windows PowerShell**: Legacy PowerShell support
- **Command Prompt**: Classic cmd with enhanced styling
- **SSH Profiles**: Preserves custom SSH configurations

### **Color Schemes**

- **Warm Nordic**: Matches your Starship prompt perfectly
- **Nordic Dark**: Classic Nordic theme
- **Dracula**: Popular dark theme
- **Solarized Dark**: Easy on the eyes

### **Enhanced Settings**

- **JuliaMono Nerd Font Mono**: Optimized for icons and readability
- **Acrylic Background**: Modern glass effect (85% opacity)
- **Warm Nordic Cursor**: `#e25822` to match theme
- **Atlas Engine**: Modern rendering for better performance
- **Auto-Backup**: Safely preserves existing settings

### **Keybindings**

- `Ctrl+Shift+T`: New tab
- `Ctrl+Shift+N`: New window
- `Ctrl+Tab`: Next tab
- `Alt+Shift+D`: Split pane
- `Ctrl+,`: Open settings
- `Ctrl+=/-`: Font size adjustment

## 🌟 **Starship Prompt Features**

### **Modern Formatting**

- Consistent bracketing with `\[[...]($style)\]` format
- Clean, organized appearance with proper spacing
- Version information for all programming languages
- **Warm Nordic Color Palette**: Custom hex colors for better visual hierarchy

### **Color Scheme**

- `#e25822` - User/character (warm orange)
- `#e76f51` - Directory (coral)
- `#f4a261` - Git/branch (peach)
- `#f6aa1c` - Package/time (golden yellow)
- `#e63946` - Error/status (red)
- `#4c566a` - Version/languages (slate gray)

### **Language Support**

- **Node.js**: Shows version with 󰎙 icon
- **Python**: Shows version and virtual environment
- **Rust**: Shows version with icon
- **Go**: Shows version with icon
- **PHP**: Shows version with icon
- **Ruby**: Shows version with icon
- **Java**: Shows version with icon
- **Scala**: Shows version with icon
- **Elixir**: Shows version and OTP version
- **Swift**: Shows version with icon
- **OCaml**: Shows version and switch info
- **Erlang**: Shows version with icon
- **Crystal**: Shows version with icon
- **Dart**: Shows version with icon
- **Deno**: Shows version with icon
- **Haskell**: Shows version with icon
- **Julia**: Shows version with icon
- **Kotlin**: Shows version with icon
- **Lua**: Shows version with icon
- **Nim**: Shows version with icon
- **Perl**: Shows version with icon
- **Purescript**: Shows version with icon
- **R**: Shows version with icon
- **Red**: Shows version with icon
- **Solidity**: Shows version with icon
- **V**: Shows version with icon
- **Zig**: Shows version with icon
- **Swift**: Shows version with icon
- **OCaml**: Shows version and switch info
- **Erlang**: Shows version with icon

### **Development Tools**

- **Package**: Shows package version with 📦 icon
- **Git**: Shows branch with icon and status indicators
- **Git Status**: Shows ahead/behind, modified, staged, untracked files

### **Cloud & Infrastructure**

- **AWS**: Shows profile, region, and duration
- **Google Cloud**: Shows account, domain, and region
- **Kubernetes**: Shows context and namespace
- **Docker**: Shows context with 󰡨 icon
- **Terraform**: Shows workspace with icon

### **System Information**

- **Memory Usage**: Shows RAM and swap usage with 󰍛 icon
- **Command Duration**: Shows execution time for slow commands
- **Time**: Shows current time

### **Status Indicators**

- **Git Status**:
  - `⇡` ahead, `⇣` behind, `⇕` diverged
  - `?` untracked, `≡` stashed, `!` modified
  - `+` staged, `»` renamed, `✘` deleted

## 🔒 **Security Features**

- No secrets in dotfiles (use environment variables)
- Secure git configuration
- Cross-platform compatibility
- Proper file permissions

## 🐧 **Cross-Platform Support**

- ✅ **macOS**: Full support with Homebrew (zsh/bash)
- ✅ **Linux**: Full support with apt (Ubuntu, Debian, CentOS, etc.)
- ✅ **WSL2**: Full support with apt (Windows Subsystem for Linux)
- ✅ **Any shell**: Works with zsh, bash, and other shells
- ✅ **Relative paths**: Works across different home directory structures
- ✅ **Automatic detection**: OS and tool detection with fallbacks
- ✅ **Executable scripts**: All scripts are properly chmod'd for execution

## 📦 **Package Management**

### **macOS (Homebrew)**

```bash
brew install lsd bat ripgrep fd fzf lazygit tealdeer atuin direnv asdf starship htop ncdu procs ripgrep-all git-delta git-fuzzy
```

### **Linux/WSL (apt)**

```bash
sudo apt install lsd bat ripgrep fd-find fzf lazygit tldr direnv htop ncdu procs ripgrep-all git-delta
```

## 🚀 **Performance Benchmarks**

- **Shell startup**: < 100ms with zsh-defer
- **Plugin loading**: Async and non-blocking
- **Completions**: Cached and fast
- **Prompt rendering**: < 10ms with Starship

## 🔧 **Troubleshooting**

### Common Issues

#### "cannot execute: required file not found"

```bash
# Make scripts executable
chmod +x install-symlinks.sh dotfiles.sh uninstall-symlinks.sh symlink-dir.sh

# Then run the installer
./install-symlinks.sh
```

#### "command not found: realpath"

The scripts have fallbacks for systems without `realpath`. They will use Python3, Node.js, or absolute paths as alternatives.

#### Permission Denied

```bash
# Check file permissions
ls -la install-symlinks.sh

# Fix if needed
chmod +x install-symlinks.sh
```

### Cross-Platform Compatibility

The scripts now use:

- `#!/usr/bin/env bash` instead of `#!/bin/zsh` for maximum compatibility
- OS detection with fallbacks for different Linux distributions
- Multiple fallback methods for relative path calculation
- Cross-platform `read` command syntax

## 🤝 **Contributing**

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test on both macOS and WSL
5. Submit a pull request

## 📄 **License**

MIT License - see LICENSE file for details

## 🙏 **Acknowledgments**

- [zinit](https://github.com/zdharma-continuum/zinit) - Fast plugin manager
- [Starship](https://starship.rs/) - Fast prompt
- [zsh-defer](https://github.com/romkatv/zsh-defer) - Lazy loading
- [Modern Unix](https://github.com/ibraheemdev/modern-unix) - Tool inspiration

# Cross-Platform Dotfiles

A robust, cross-platform dotfiles management system that works seamlessly on macOS, Linux, and WSL2 Ubuntu.

## 🚀 Features

- **Cross-Platform**: Works on macOS, Linux, and WSL2
- **Robust Path Detection**: Uses `BASH_SOURCE` for reliable script location
- **Dynamic Aliases**: Functions that work from any directory
- **Multiple Installation Locations**: Supports `~/dotfiles` and `~/.dotfiles`
- **Robust Symlink Creation**: Multiple fallback methods (Python, Node.js, traditional `ln`)
- **Smart OS Detection**: Automatically detects platform and uses appropriate tools
- **Debug Mode**: Detailed troubleshooting with `--debug` flag
- **Diagnostic Tools**: Built-in diagnostic script to identify issues
- **Safe Installation**: Creates backups before overwriting existing files
- **Modern Tools**: Includes zsh-defer, atuin, direnv, asdf, git-delta, and more

## 📦 Included Tools

### Core Tools

- **zsh-defer**: Lazy loading for faster shell startup
- **direnv**: Auto environment switching
- **git-delta**: Better git diff viewer
- **git-fuzzy**: Fuzzy git interface
- **starship**: Fast, customizable prompt with modern formatting
- **lsd**: Modern `ls` replacement
- **zinit**: Fast zsh plugin manager

### Development Tools

- **gh**: GitHub CLI
- **bat**: Better `cat` with syntax highlighting
- **fd**: Fast `find` alternative
- **ripgrep**: Fast `grep` alternative
- **fzf**: Fuzzy finder

## 🛠️ Installation

### Quick Start

```bash
# Clone the repository
git clone <your-repo-url> dotfiles
cd dotfiles

# Install dotfiles (symlinks only - no sudo required)
./dotfiles.sh install

# Or use the interactive menu
./dotfiles.sh

# Install tools (optional - may require sudo)
./install-tools.sh

# Or with debug mode for troubleshooting
./dotfiles.sh --debug install
```

### Manual Installation

1. **Clone the repository**:

   ```bash
   git clone <your-repo-url> dotfiles
   cd dotfiles
   ```

2. **Install dotfiles** (creates symlinks):

   ```bash
   ./dotfiles.sh install

   # Or use the interactive menu
   ./dotfiles.sh
   ```

3. **Install tools** (optional, installs modern CLI tools):

   ```bash
   ./install-tools.sh
   ```

4. **Restart your shell** or run:
   ```bash
   source ~/.zshrc
   ```

## 🔧 Usage

### Basic Commands

#### Interactive Menu (Recommended)

```bash
# Run the interactive menu
./dotfiles.sh

# Or explicitly run menu
./dotfiles.sh menu
```

#### Command Line

```bash
# Install all dotfiles
./dotfiles.sh install

# Check current status
./dotfiles.sh status

# Uninstall dotfiles
./dotfiles.sh uninstall

# Manage .zshrc only
./dotfiles.sh zshrc install
./dotfiles.sh zshrc uninstall
./dotfiles.sh zshrc status

# Get help
./dotfiles.sh help
```

### Tool Installation

Tools are now checked only once per day to avoid startup delays. To manually install or update tools:

```bash
# Install/update all tools
./install-tools.sh

# Or force re-check tools (removes daily cache)
rm /tmp/dotfiles_tools_checked_*
```

### Debug Mode

For troubleshooting, use debug mode:

```bash
# Install with detailed logging
./dotfiles.sh --debug install

# Run diagnostics
./diagnose.sh
```

### Uninstall Options

```bash
# Safe uninstall (symlinks only)
./dotfiles.sh uninstall

# Restore backups
./dotfiles.sh uninstall restore

# Full cleanup (including tools)
./dotfiles.sh uninstall full
```

## 🔍 Troubleshooting

### Diagnostic Tool

Run the built-in diagnostic tool to identify issues:

```bash
./diagnose.sh
```

This will check:

- ✅ OS detection
- ✅ Required tools (Python, Node.js, Git)
- ✅ Package managers (Homebrew, APT)
- ✅ Configuration file
- ✅ Source files
- ✅ Existing symlinks
- ✅ Symlink creation capability
- ✅ File permissions

### Common Issues

#### Broken Symlinks

```bash
# Check for broken symlinks
./diagnose.sh

# Reinstall with debug mode
./dotfiles.sh --debug install
```

#### Missing Files

```bash
# Verify source files exist
ls -la .config/zsh/

# Reinstall from correct directory
cd /path/to/dotfiles
./dotfiles.sh install
```

#### Permission Issues

```bash
# Check permissions
ls -la ~/.config/zsh/

# Fix permissions if needed
chmod 755 ~/.config/zsh/
```

## 🎨 Architecture

### **Cross-Platform Path Detection**

All scripts use robust path detection that works regardless of:

- **Installation location**: `~/dotfiles` or `~/.dotfiles`
- **Current directory**: Commands work from anywhere
- **Platform**: macOS, Linux, WSL2
- **Shell**: zsh, bash

```bash
# Reliable script location detection
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
```

### **Dynamic Function-Based Commands**

Instead of hardcoded aliases, the system uses functions that:

- ✅ **Auto-detect** dotfiles location
- ✅ **Work from any directory**
- ✅ **Support multiple installation paths**
- ✅ **Provide clear error messages**

```bash
# These work from anywhere
dotfiles install
dotfiles list
install-tools
```

### **File Structure**

```
dotfiles/
├── .zshrc                    # Main zsh configuration
├── .gitconfig               # Git configuration
├── .gitignore_global        # Global gitignore
├── .config/
│   ├── zsh/
│   │   ├── aliases          # Shell aliases and functions
│   │   ├── plugins          # Plugin configuration
│   │   └── env              # Environment variables
│   ├── ghostty/config       # Terminal configuration
│   └── starship.toml        # Prompt configuration with modern formatting
├── scripts/
│   ├── dotfiles.sh          # Main installer script
│   ├── dotfiles.conf        # Configuration file
│   ├── diagnose.sh          # Diagnostic tool
│   ├── install-tools.sh     # Tool installation
│   ├── main.sh              # Unified menu
│   └── version.sh           # Version management
└── README.md
```

## ⚙️ Configuration

### Adding New Files

Edit `dotfiles.conf`:

```bash
# Format: source_file:target_location:description
.config/nvim/init.lua:~/.config/nvim/init.lua:Neovim configuration
```

### Customizing Tools

Edit the appropriate configuration file:

- **Shell**: `.config/zsh/aliases` and `.config/zsh/plugins`
- **Git**: `.gitconfig`
- **Terminal**: `.config/ghostty/config`
- **Prompt**: `.config/starship.toml`

## 🔄 Updates

```bash
# Update dotfiles
git pull origin main

# Reinstall to apply changes
./dotfiles.sh install
```

## 📝 License

This project is open source and available under the [MIT License](LICENSE).

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test on both macOS and WSL2
5. Submit a pull request

## 🐛 Bug Reports

If you encounter issues:

1. Run the diagnostic tool: `./diagnose.sh`
2. Try debug mode: `./dotfiles.sh --debug install`
3. Check the troubleshooting section above
4. Open an issue with diagnostic output

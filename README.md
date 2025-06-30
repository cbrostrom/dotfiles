# 🚀 Optimized Dotfiles for Web Development 2025

A cross-platform dotfiles setup optimized for modern web development with performance, security, and developer experience in mind.

## ✨ Features

### 🎯 **Performance Optimizations**
- **zsh-defer**: Lazy loading for faster shell startup
- **zinit**: Fast plugin manager with async loading
- **Starship**: Ultra-fast prompt written in Rust
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
git clone https://github.com/yourusername/dotfiles.git ~/dotfiles
cd ~/dotfiles

# Run the installer
./scripts/install.sh

# Install dotfiles
dotfiles install

# Restart your shell or source your rc file
source ~/.zshrc
```

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
- ✅ **Starship**: Rust-based prompt
- ✅ **Async completions**: Non-blocking completion loading

### **Modern Tools**
- ✅ **lsd**: Replaced `eza` with more maintained alternative
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
- ✅ **Starship**: Modern, fast prompt
- ✅ **zsh-autocomplete**: Better completions
- ✅ **zsh-syntax-highlighting**: Syntax highlighting

### **Cross-Platform Tools**
- ✅ **ripgrep-all**: Search in all file types
- ✅ **fd**: Fast file finding
- ✅ **procs**: Better process listing

## 🔧 **Configuration Files**

### **Shell Configuration**
- `.zshrc`: Main shell configuration
- `.config/zsh/aliases`: Command aliases
- `.config/zsh/plugins`: Plugin management
- `.config/zsh/env`: Environment variables

### **Git Configuration**
- `.gitconfig`: Git settings with delta integration
- `.gitignore_global`: Global gitignore

### **Terminal Configuration**
- `.config/ghostty/config`: Ghostty terminal
- `.config/starship.toml`: Starship prompt

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

## 🌟 **Starship Prompt Features**

- Git status with detailed indicators
- Language-specific version info
- Memory usage monitoring
- Command duration for slow commands
- Cloud provider context (AWS, GCP)
- Docker and Kubernetes context
- Custom project type detection

## 🔒 **Security Features**

- No secrets in dotfiles (use environment variables)
- Secure git configuration
- Cross-platform compatibility
- Proper file permissions

## 🐧 **Cross-Platform Support**

- ✅ **macOS**: Full support with Homebrew
- ✅ **WSL2 Ubuntu**: Full support with apt
- ✅ **Linux**: Full support with apt
- ✅ **Relative paths**: Works across different home directory structures

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

A robust, cross-platform dotfiles management system that works seamlessly on macOS and WSL2 Ubuntu.

## 🚀 Features

- **Cross-Platform**: Works on macOS, Linux, and WSL2
- **Robust Symlink Creation**: Multiple fallback methods (Python, Node.js, traditional `ln`)
- **Smart OS Detection**: Automatically detects platform and uses appropriate tools
- **Debug Mode**: Detailed troubleshooting with `--debug` flag
- **Diagnostic Tools**: Built-in diagnostic script to identify issues
- **Safe Installation**: Creates backups before overwriting existing files
- **Modern Tools**: Includes zsh-defer, atuin, direnv, asdf, git-delta, and more

## 📦 Included Tools

### Core Tools
- **zsh-defer**: Lazy loading for faster shell startup
- **atuin**: Better shell history with search
- **direnv**: Automatic environment switching
- **asdf**: Version manager for multiple languages
- **git-delta**: Better git diffs
- **git-fuzzy**: Interactive git tools
- **starship**: Fast, customizable prompt
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

# Install dotfiles
./scripts/dotfiles.sh install

# Or with debug mode for troubleshooting
./scripts/dotfiles.sh --debug install
```

### Manual Installation

1. **Clone the repository**:
   ```bash
   git clone <your-repo-url> dotfiles
   cd dotfiles
   ```

2. **Run the installer**:
   ```bash
   ./scripts/dotfiles.sh install
   ```

3. **Restart your shell** or run:
   ```bash
   source ~/.zshrc
   ```

## 🔧 Usage

### Basic Commands

```bash
# Install all dotfiles
./scripts/dotfiles.sh install

# List current status
./scripts/dotfiles.sh list

# Uninstall (with options)
./scripts/dotfiles.sh uninstall

# Get help
./scripts/dotfiles.sh help
```

### Debug Mode

For troubleshooting, use debug mode:

```bash
# Install with detailed logging
./scripts/dotfiles.sh --debug install

# Run diagnostics
./scripts/diagnose.sh
```

### Uninstall Options

```bash
# Safe uninstall (symlinks only)
./scripts/dotfiles.sh uninstall

# Restore backups
./scripts/dotfiles.sh uninstall restore

# Full cleanup (including tools)
./scripts/dotfiles.sh uninstall full
```

## 🔍 Troubleshooting

### Diagnostic Tool

Run the built-in diagnostic tool to identify issues:

```bash
./scripts/diagnose.sh
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
./scripts/diagnose.sh

# Reinstall with debug mode
./scripts/dotfiles.sh --debug install
```

#### Missing Files
```bash
# Verify source files exist
ls -la .config/zsh/

# Reinstall from correct directory
cd /path/to/dotfiles
./scripts/dotfiles.sh install
```

#### Permission Issues
```bash
# Check permissions
ls -la ~/.config/zsh/

# Fix permissions if needed
chmod 755 ~/.config/zsh/
```

## 🏗️ Architecture

### File Structure
```
dotfiles/
├── .zshrc                    # Main zsh configuration
├── .gitconfig               # Git configuration
├── .gitignore_global        # Global gitignore
├── .config/
│   ├── zsh/
│   │   ├── aliases          # Shell aliases
│   │   ├── plugins          # Plugin configuration
│   │   └── env              # Environment variables
│   ├── ghostty/config       # Terminal configuration
│   └── starship.toml        # Prompt configuration
├── scripts/
│   ├── dotfiles.sh          # Main installer script
│   ├── dotfiles.conf        # Configuration file
│   ├── diagnose.sh          # Diagnostic tool
│   └── main.sh              # Unified menu
└── README.md
```

### Symlink Creation

The installer uses multiple methods for reliable symlink creation:

1. **Python3** (primary): `os.symlink()` with `os.path.relpath()`
2. **Node.js** (fallback): `fs.symlinkSync()` with `path.relative()`
3. **Traditional** (last resort): `ln -sf` with manual path calculation

### Cross-Platform Compatibility

- **macOS**: Uses Homebrew for package management
- **Linux/WSL**: Uses APT for package management
- **Path Handling**: Always uses relative paths for symlinks
- **OS Detection**: Automatic detection with fallbacks

## ⚙️ Configuration

### Adding New Files

Edit `scripts/dotfiles.conf`:

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
./scripts/dotfiles.sh install
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

1. Run the diagnostic tool: `./scripts/diagnose.sh`
2. Try debug mode: `./scripts/dotfiles.sh --debug install`
3. Check the troubleshooting section above
4. Open an issue with diagnostic output
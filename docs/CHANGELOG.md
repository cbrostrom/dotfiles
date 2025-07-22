# Changelog

## [1.0.0] - 2025-01-22

### 🎉 Major Release - Streamlined Installation System

This is a complete rewrite of the dotfiles system, providing a streamlined, single-command installation experience.

### ✨ New Features

#### 🚀 **Single Command Installation**

- **`./install.sh`** - Complete installation (dependencies + dotfiles)
- **`./uninstall.sh`** - Remove dotfiles and restore backups
- **`./status.sh`** - Check status of all components
- **`./dotfiles.sh`** - Modern menu interface

#### 🎯 **Interactive Menu System**

- Beautiful, cross-platform menu interface
- Available via `dotfiles` command from anywhere
- Options for install, uninstall, status, update, dry-run
- Automatic git update detection

#### 🔧 **Smart Installation**

- Automatic OS detection (macOS, Linux, WSL2)
- Platform-specific package managers (Homebrew, apt, yum, dnf)
- Relative symlinks for portability
- Comprehensive error handling and rollback
- Dry-run mode for preview

#### 📊 **Status Checking**

- Comprehensive status reporting
- Tool installation verification
- Symlink status checking
- Directory existence validation
- Shell configuration status

#### 🔄 **Update System**

- `dotfiles update` - Git pull + reinstall
- Automatic update detection in menu
- Safe update process with rollback

### 🛠️ Technical Improvements

#### **Cross-Platform Compatibility**

- Robust OS detection with fallbacks
- Multiple package manager support
- Terminal compatibility fixes
- Relative path handling

#### **Development Environment**

- **zsh** with zinit plugin manager
- **starship** prompt (cross-platform)
- **lsd, bat, ripgrep, fzf** (modern Unix tools)
- **Node.js, Go, Rust** (programming languages)
- **direnv, asdf** (environment management)

#### **Platform-Specific Features**

- **macOS**: Ghostty terminal config, Homebrew integration
- **Linux**: xterm-256color terminal fix, apt/yum/dnf support
- **WSL2**: Windows Terminal integration

### 📁 **File Organization**

#### **Root Directory (Clean)**

```
dotfiles/
├── install.sh          # Main installer (v1.0)
├── uninstall.sh        # Uninstaller
├── status.sh           # Status checker
├── dotfiles.sh         # Menu interface
├── README.md           # Updated documentation
├── MIGRATION.md        # Migration guide
├── CHANGELOG.md        # This file
├── VERSION             # Version tracking
├── .zshrc              # Shell configuration
├── .gitconfig          # Git configuration
├── .config/            # Application configs
└── utils/              # Legacy scripts (deprecated)
```

#### **Legacy Scripts (Moved to utils/)**

- `install-symlinks.sh` → `utils/`
- `uninstall-symlinks.sh` → `utils/`
- `setup-debian-zsh.sh` → `utils/`
- `install-starship-direnv.sh` → `utils/`
- `fix-debian-terminal.sh` → `utils/`
- `test-cross-platform.sh` → `utils/`
- `test-terminal.sh` → `utils/`
- `symlink-dir.sh` → `utils/`
- `WSL-SETUP.md` → `utils/`

### 🎯 **Usage Examples**

#### **Quick Start**

```bash
git clone <repo> ~/dotfiles
cd ~/dotfiles
./install.sh
```

#### **Menu System**

```bash
dotfiles                    # Show interactive menu
dotfiles install            # Full installation
dotfiles install --skip-deps # Only install dotfiles
dotfiles uninstall          # Remove dotfiles
dotfiles status             # Check status
dotfiles update             # Update from git
dotfiles dry-run            # Preview installation
```

#### **Direct Script Usage**

```bash
./install.sh                # Full installation
./install.sh --skip-deps    # Only install dotfiles
./install.sh --dry-run      # Preview installation
./uninstall.sh              # Remove dotfiles
./status.sh                 # Check status
```

### 🔄 **Migration from v0.x**

- **Backward Compatibility**: Old scripts still work (moved to `utils/`)
- **Migration Guide**: See `MIGRATION.md` for detailed instructions
- **Easy Rollback**: Can revert to old system if needed
- **Preserved Data**: All existing configurations maintained

### 🐛 **Bug Fixes**

- Fixed terminal compatibility issues on Linux/Debian
- Improved symlink creation with multiple fallbacks
- Better error handling and user feedback
- Fixed backspace issues on Debian systems
- Resolved package manager detection issues

### 📚 **Documentation**

- **README.md**: Complete rewrite with v1.0 focus
- **MIGRATION.md**: Detailed migration guide
- **utils/README.md**: Legacy script documentation
- **CHANGELOG.md**: This comprehensive changelog

### 🎨 **User Experience**

- **Simplified Workflow**: One command instead of multiple scripts
- **Better Feedback**: Colored output and clear status messages
- **Interactive Menu**: User-friendly interface
- **Update Detection**: Automatic notification of available updates
- **Dry-Run Mode**: Preview changes before applying

### 🔒 **Security & Reliability**

- **Safe Installation**: Creates backups before overwriting
- **Rollback Support**: Easy uninstallation and restoration
- **Error Handling**: Comprehensive error checking and recovery
- **Cross-Platform**: Tested on macOS, Linux, and WSL2

---

## [0.3.0] - Previous Version

### Features

- Multi-script installation system
- Interactive menu with legacy scripts
- Cross-platform compatibility
- Basic dotfiles management

### Limitations

- Complex workflow with multiple scripts
- Legacy script dependencies
- Manual update process
- Limited status checking

---

_This changelog documents the transition from the legacy v0.x system to the streamlined v1.0 system._

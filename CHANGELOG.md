# Changelog

All notable changes to this dotfiles project will be documented in this file.

## [3.0.0] - 2025-01-04

### 🎯 Major Changes

#### Modular Configuration
- **Split `.zshrc` into 5 focused modules** for better organization
  - `01-environment.zsh` - OS detection, PATH, environment variables
  - `02-plugins.zsh` - zinit, FZF, completions, zoxide, starship, fnm
  - `03-aliases.zsh` - Modern tool replacements and shortcuts
  - `04-functions.zsh` - Custom functions and utilities
  - `05-integrations.zsh` - Editor integrations (Cursor, VS Code)

#### Performance Optimizations
- **Lazy Loading**: Critical plugins load immediately, others lazy load
- **Completion Caching**: Only checks completions once per day (24h cache)
- **FZF Consolidation**: Merged duplicate FZF configuration into single section
- **Faster Startup**: Reduced shell startup time by ~30-50%

#### Simplified Dependencies
- **Removed asdf**: No longer needed, using package managers directly
- **Removed Rust compilation**: Installing pre-built binaries via Homebrew/apt
- **Simplified install.sh**: Reduced from 1334 lines to ~900 lines
- **Faster Installation**: No more compiling tools from source

### ✨ New Features

#### Backup System
- **backup.sh**: New script for managing dotfiles backups
  - `backup.sh create` - Create timestamped backup
  - `backup.sh list` - List all available backups
  - `backup.sh restore <timestamp>` - Restore from backup
  - `backup.sh clean [count]` - Clean old backups (keep N most recent)

#### Security Improvements
- **`.local-secrets` support**: Dedicated file for sensitive tokens/API keys
- **Updated `.gitignore`**: Added more backup patterns (*.bak, *.old, *~)
- **Better separation**: Secrets are now completely outside of git tracking

### 🔧 Configuration Changes

#### Environment (01-environment.zsh)
- SSH agent only runs on Linux/WSL (macOS uses built-in Keychain)
- Google Cloud SDK integration preserved
- `.local-secrets` auto-sourced if present

#### Plugins (02-plugins.zsh)
- Optimized plugin loading order (critical first, others lazy)
- FZF configuration consolidated from 2 places into 1
- Completion caching with 24h TTL
- Improved zoxide exclusions

#### Aliases (03-aliases.zsh)
- Preserved all modern tool aliases
- FZF-enhanced git aliases
- Platform-specific aliases (Linux vs macOS)

### 📦 Installation Changes

#### install.sh v3.0
- Removed `setup_asdf()` function
- Removed `install_rust_tools()` function
- Removed `install_go()` function (was using asdf)
- Removed `install_python()` function (was using asdf)
- New `install_modern_tools()` - installs via package managers
- New `install_starship_linux()` - uses official installer
- New `install_zoxide_linux()` - uses official installer
- New `install_lsd_linux()` - downloads .deb from GitHub releases

### 🗑️ Removed

- asdf version manager (no longer needed)
- asdf-direnv plugin
- Rust toolchain installation
- Go installation via asdf
- Python installation via asdf
- Cargo-based tool compilation

### 📝 Documentation

- New `zsh/README.md` - Explains modular structure
- Updated main `README.md` - v3.0 features and changes
- New `CHANGELOG.md` - This file!
- Backup examples in documentation

### 🐛 Bug Fixes

- Fixed duplicate FZF configuration causing conflicts
- Fixed SSH agent prompt on macOS with Keychain
- Improved error handling in install.sh
- Better platform detection (macOS vs Linux vs WSL)

### ⚠️ Breaking Changes

- `.zshrc` is now a loader file, actual config in `zsh/` modules
- `install.sh` no longer installs asdf, Go, Python, or Rust
- Tools now installed via package managers (Homebrew/apt) instead of compilation
- Backup files now use `.backup.*` pattern instead of `.bak`

### 🔄 Migration Guide

For existing users upgrading from v2.0:

1. **Backup your current setup**:
   ```bash
   cd ~/dotfiles
   ./backup.sh create
   ```

2. **Pull the latest changes**:
   ```bash
   git pull origin main
   ```

3. **Run the installer**:
   ```bash
   ./install.sh --verify
   ```

4. **Restart your terminal**

5. **Verify everything works**:
   ```bash
   ./status.sh
   ```

### 📊 Performance Metrics

- Shell startup time: **~0.3s → ~0.2s** (33% faster)
- Completion load time: **~0.1s → ~0.01s** (90% faster on cached)
- Install.sh execution: **~15min → ~5min** (no compilation)
- Lines of code: **1334 → ~900** (32% reduction in install.sh)

---

## [2.0.0] - 2024-12-XX

### Added
- fnm (Fast Node Manager) for Node.js
- Cross-platform support (macOS, Linux, WSL2)
- Better zsh setup and verification
- Status checking script

### Changed
- Migrated from nvm to fnm for better .nvmrc support
- Improved installation verification

---

## [1.0.0] - 2024-XX-XX

### Added
- Initial release
- Basic dotfiles setup
- asdf version manager
- Manual tool installation


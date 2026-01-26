# Changelog

All notable changes to this project will be documented in this file.

## [3.1.0] - 2026-01-26

### Added
- **Hyprland migration guide** with complete system config preservation
  - Full backup/restore scripts for fstab, Samba mounts, and configs
  - Pre-configured Hyprland + Sunshine setup for game streaming
  - Display management that actually works (no more HDMI priority issues)
- **Scripts organization** - Moved utility scripts to `scripts/` directory
  - `scripts/cursor/` for Cursor IDE management
  - `scripts/migrate-to-fnm.sh` for Node.js migration

### Changed
- **README updated** to reflect current system (Gnome) not future plans
- **Cleaned up obsolete files**:
  - Removed outdated documentation (ASDF, completion optimizations, migrations)
  - Removed test/debug scripts (debug-install.sh, test-*.sh)
  - Removed old fix scripts (fix-zsh.sh, fix-direnv.sh) - integrated into install.sh
  - Removed backup files (.zshrc.backup, install.sh.backup)
- **Moved apollo-steam-sync README** to utils/APOLLO-STEAM-SYNC.md

### Removed
- Old asdf-related documentation and scripts
- Obsolete gaming scripts (test-avatar.sh, ubisoft-cleanup.sh)
- Debug and test scripts
- Duplicate fix scripts

### Focus
Dotfiles now focus on **symlinked configs** and **useful utilities** rather than monolithic installers.

---

## [3.0.0] - 2025-01-22

### Major Changes
- Complete rewrite with modular .zshrc (5 focused modules)
- Performance optimizations (lazy loading, completion caching)
- Switched from asdf to fnm for Node.js management
- New backup.sh system for safe updates
- Local config tracking (.local-config)
- Platform-specific configs (Linux/macOS separated)

### Technical
- Relative symlinks for portability
- Cross-platform compatibility
- Smart installation with dry-run mode
- Comprehensive status checking

---

## Previous Versions

See git history for older changes.

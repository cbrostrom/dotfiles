# Dotfiles Installer - Interactive Menu Guide

## Quick Start

### Default (Interactive Menu)
```bash
./install.sh
```
Shows an interactive menu where you can choose what to install.

## Menu Options

### 1) Full Setup (Recommended)
Installs everything sequentially:
- All dependencies (zsh, git, curl, etc.)
- Development tools (Node.js via fnm, modern CLI tools)
- All dotfiles and configs
- Gaming launcher and presets
- Platform-specific configs (Ghostty, etc.)

**Use when:** Fresh installation or complete setup

### 2) Minimal Setup
Installs only the basics:
- Essential packages (zsh, git)
- Basic dotfiles (.zshrc, .gitconfig, starship)

**Use when:** You just want the core shell setup

### 3) Custom Components
Choose exactly what you want:
- [ ] Dependencies
- [ ] Development Tools
- [ ] Basic Dotfiles
- [ ] Gaming Launcher & Presets
- [ ] Platform-Specific Configs
- [ ] Modern CLI Tools

**Use when:** You know exactly what you need

### 4) Gaming Only
Installs just the gaming launcher:
- gamelaunch command
- All 20 presets
- DXVK config templates
- Gaming documentation

**Use when:** You already have dotfiles setup and just want gaming

### 5) Platform-Specific Only
Installs platform configs:
- **macOS:** Ghostty config
- **Linux:** Ghostty + GNOME tools (if applicable)

**Use when:** You want to add platform-specific configs to existing setup

### 6) Development Tools Only
Installs development tools:
- Node.js via fnm
- Modern CLI tools (bat, eza, ripgrep, fd, fzf, etc.)

**Use when:** You want the tools but already have dotfiles

### 7) Dry Run
Shows what would be installed without actually installing

**Use when:** You want to preview before committing

## Command Line Usage

### Quick Commands
```bash
# Full setup (non-interactive)
./install.sh --full

# Minimal setup
./install.sh --minimal

# Gaming only
./install.sh --gaming

# Preview what would be installed
./install.sh --dry-run

# Show help
./install.sh --help
```

### Advanced Options
```bash
# Skip dependencies (only install dotfiles)
./install.sh --skip-deps

# Skip dotfiles (only install dependencies)
./install.sh --skip-dotfiles

# Full setup + verify installation
./install.sh --full --verify

# Full setup + update system packages
./install.sh --full --update
```

## Examples

### Fresh Linux Installation
```bash
./install.sh --full
```

### Add Gaming to Existing Setup
```bash
./install.sh --gaming
```

### Install on macOS
```bash
./install.sh  # Choose option 1 from menu
```

### Minimal Shell Setup on Server
```bash
./install.sh --minimal
```

### Custom Installation
```bash
./install.sh  # Choose option 3, then select: 1 3 4 (deps, dotfiles, gaming)
```

## What Gets Installed

### Full Setup Includes:
1. **Dependencies**
   - zsh, git, curl, wget
   - Build tools (base-devel on Arch, build-essential on Debian)
   - zinit (plugin manager)

2. **Development Tools**
   - Node.js (via fnm)
   - Modern CLI tools: bat, eza, ripgrep, fd, fzf, zoxide, bottom, procs, etc.

3. **Dotfiles**
   - .zshrc with optimized config
   - .gitconfig, .gitignore_global
   - Starship prompt config
   - lazygit, bat, procs configs

4. **Gaming**
   - gamelaunch wrapper script
   - 20 game presets
   - DXVK configuration templates
   - Comprehensive gaming documentation

5. **Platform-Specific**
   - Ghostty terminal config (macOS/Linux)
   - GNOME tools and settings (Linux GNOME only)

## Troubleshooting

### Script Fails
- Ensure you're not running as root
- Check internet connection
- Verify package manager is working

### Components Missing
- Re-run specific mode: `./install.sh --gaming`
- Check logs for errors
- Run `./status.sh` to see what's installed

### Want to Reinstall
```bash
# Backup first if needed
./install.sh --full  # Will update symlinks automatically
```

## Tips

- **First time users:** Use Full Setup
- **Existing users:** Use Custom or specific modes
- **Gaming enthusiasts:** Run `./install.sh --gaming` anytime
- **Testing:** Always use `--dry-run` first

## See Also

- Gaming Setup: `gaming/QUICKSTART.md`
- Status Check: `./status.sh`
- Uninstall: `./uninstall.sh`

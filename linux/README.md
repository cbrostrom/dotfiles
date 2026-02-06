# Linux-Specific Configurations

This directory contains Linux-specific configurations for GNOME desktop environment and terminal emulators.

## 📁 Structure

```
linux/
├── gnome/                     # GNOME desktop environment (optional)
│   ├── dconf-backup.sh        # Backup GNOME settings
│   ├── dconf-restore.sh       # Restore GNOME settings
│   ├── dconf-settings.ini     # Backed up settings
│   ├── extensions-list.txt    # Recommended extensions
│   └── install-gnome-tools.sh # Install GNOME tools
│
├── ghostty/                   # Ghostty terminal emulator
│   └── config                 # Ghostty configuration
│
├── hyprland/                  # Hyprland window manager
│   └── ...                    # Hyprland configuration
│
├── paru/                      # Paru AUR helper
│   ├── paru.conf              # Paru configuration
│   └── README.md              # Paru documentation
│
├── security/                  # Security hardening
│   ├── SSH-SECURITY.md        # SSH security guide
│   ├── README.md              # Security documentation
│   └── .gitignore             # Ignore sensitive files
│
├── install-linux.sh           # Main Linux installer
├── install-worksuite.sh       # Work suite installer
├── WORKSUITE.md               # Work suite documentation
└── README.md                  # This file
```

## 🚀 Quick Start

### Automatic Installation

The Linux-specific setup is automatically triggered when you run the main installer:

```bash
cd ~/dotfiles
./install.sh
```

The installer will:
- Detect your desktop environment
- Configure Ghostty terminal (if installed)
- Offer GNOME-specific setup (if running GNOME)

### Manual Installation

If you prefer to run the Linux installer separately:

```bash
cd ~/dotfiles/linux
./install-linux.sh
```

### Work Suite Installation

Install all work applications (Slack, Teams, Outlook, Spotify, etc.):

```bash
# Using alias (after sourcing zsh config)
worksuite

# Or directly
cd ~/dotfiles/linux
./install-worksuite.sh

# Check what's installed
worksuite-check
```

See [WORKSUITE.md](WORKSUITE.md) for detailed documentation.

## 🖥️ GNOME Desktop Environment

### GNOME Setup (Optional)

GNOME-specific configuration is **opt-in** and only relevant if you're using GNOME desktop.

The installer will automatically detect GNOME and ask if you want to install GNOME-specific tools.

#### Manual GNOME Setup

```bash
cd ~/dotfiles/linux/gnome
./install-gnome-tools.sh
```

This installs:
- **GNOME Tweaks** - Advanced GNOME settings
- **GNOME Shell Extensions** - Extension support
- **dconf-editor** - GUI editor for dconf settings
- **GNOME Browser Connector** - Install extensions from browser

### Backup GNOME Settings

Backup your current GNOME configuration:

```bash
cd ~/dotfiles/linux/gnome
./dconf-backup.sh
```

This backs up:
- Desktop interface settings (theme, fonts, dark mode)
- Window manager settings
- GNOME Shell configuration
- Custom keybindings
- Terminal settings
- Enabled extensions list

Output files:
- `dconf-settings.ini` - All GNOME settings
- `extensions-enabled.txt` - List of enabled extensions

### Restore GNOME Settings

Restore your GNOME configuration on a new machine:

```bash
cd ~/dotfiles/linux/gnome
./dconf-restore.sh
```

**Note:** This will overwrite your current settings. Make a backup first if needed.

After restore:
- **X11**: Press `Alt+F2`, type `r`, press Enter to restart GNOME Shell
- **Wayland**: Log out and log back in

### Recommended GNOME Extensions

See `gnome/extensions-list.txt` for a curated list of recommended extensions.

Popular extensions include:
- **Dash to Dock** - macOS-like dock
- **AppIndicator Support** - System tray icons
- **Clipboard Indicator** - Clipboard history
- **User Themes** - Custom shell themes
- **Vitals** - System monitoring

Install extensions from: https://extensions.gnome.org/

## 📟 Ghostty Terminal

### Configuration

Ghostty configuration is automatically symlinked during installation:

```
~/.config/ghostty/config -> ~/dotfiles/linux/ghostty/config
```

### Customization

Edit `linux/ghostty/config` to customize:
- Font family and size
- Color theme
- Window padding
- Keybindings
- Shell integration

See all options: `ghostty +show-config --default --docs`

Reload config: `Ctrl+Shift+,` (Linux)

### Installation

If Ghostty is not installed:

```bash
# Arch/CachyOS (AUR)
yay -S ghostty

# Or download from: https://ghostty.org/
```

## 🎨 Desktop Environment Detection

The installer automatically detects your desktop environment:

- **GNOME** - Offers GNOME-specific setup
- **KDE Plasma** - Basic setup (no specific configs yet)
- **XFCE** - Basic setup (no specific configs yet)
- **Other** - Basic setup only

Your desktop environment is saved in `.local-config`:

```bash
cat ~/dotfiles/.local-config
# DESKTOP_ENV="gnome"
```

## 🔧 Customization

### Add Your Own Configs

To add more Linux-specific configs:

1. Create a new directory in `linux/` (e.g., `linux/kde/`)
2. Add your configuration files
3. Update `linux/install-linux.sh` to symlink them
4. Update this README

### Platform-Specific Settings

Use `.local-config` to track machine-specific settings:

```bash
# View current config
cat ~/dotfiles/.local-config

# Example content:
PLATFORM="linux"
DESKTOP_ENV="gnome"
INSTALLED_OPTIONALS="gnome-tools,ghostty"
MACHINE_NAME="my-workstation"
```

## 🐛 Troubleshooting

### GNOME Settings Not Applying

```bash
# Check if dconf is installed
which dconf

# Install if missing (Arch/CachyOS)
sudo pacman -S dconf

# Restart GNOME Shell
# X11: Alt+F2, type 'r', press Enter
# Wayland: Log out and log back in
```

### Ghostty Config Not Loading

```bash
# Check if symlink exists
ls -la ~/.config/ghostty/config

# Manually create symlink
ln -sf ~/dotfiles/linux/ghostty/config ~/.config/ghostty/config

# Verify Ghostty is installed
which ghostty
ghostty --version
```

### Desktop Environment Not Detected

```bash
# Check current desktop
echo $XDG_CURRENT_DESKTOP
echo $DESKTOP_SESSION

# Manually set in .local-config
echo 'DESKTOP_ENV="gnome"' >> ~/dotfiles/.local-config
```

## 📚 Resources

- [GNOME Documentation](https://help.gnome.org/)
- [GNOME Extensions](https://extensions.gnome.org/)
- [Ghostty Documentation](https://ghostty.org/docs)
- [dconf Manual](https://wiki.gnome.org/Projects/dconf)
- [Arch Wiki - GNOME](https://wiki.archlinux.org/title/GNOME)

## 🤝 Contributing

To add support for other desktop environments (KDE, XFCE, etc.):

1. Create a new directory: `linux/<desktop>/`
2. Add installation script: `install-<desktop>-tools.sh`
3. Update `linux/install-linux.sh` to detect and handle the new DE
4. Update this README with documentation

## 📝 Notes

- GNOME setup is **optional** and only runs if you confirm
- Ghostty config is cross-platform (also works on macOS)
- All scripts are non-destructive and ask for confirmation
- Backup scripts preserve your existing settings
- `.local-config` tracks what's installed on each machine

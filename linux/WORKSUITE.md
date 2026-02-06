# Work Suite Setup

Complete work environment setup for Linux (CachyOS/Arch-based systems).

## 📦 Included Applications

### Communication & Productivity
- **Slack** - Team communication platform
- **Microsoft Teams** - Video conferencing and collaboration
- **Microsoft Outlook** - Work email client
- **Betterbird** - Email client for private emails (Thunderbird fork)
- **Beeper** - Unified messaging (WhatsApp, Signal, Telegram, Discord, iMessage)

### Development & Tools
- **Ghostty** - Modern, GPU-accelerated terminal emulator
- **Cursor** - AI-powered code editor (VSCode fork)
- **Vivaldi** - Feature-rich web browser

### Media
- **Spotify** - Music streaming service

## 🚀 Installation

### Quick Install (All Packages)

```bash
# From dotfiles root
./linux/install-worksuite.sh

# Or directly
cd ~/.config/dotfiles/linux
./install-worksuite.sh
```

### Check Installation Status

```bash
./linux/install-worksuite.sh --check-only
```

### Manual Installation

If you prefer to install packages manually:

```bash
# Official packages (pacman)
sudo pacman -S teams-for-linux spotify-launcher betterbird-bin

# AUR packages (paru)
paru -S slack-desktop outlook-for-linux-bin ghostty cursor-bin vivaldi beeper-v4-bin
```

## 📝 Package Details

### Official Packages (pacman)

| Package | Description | Source |
|---------|-------------|--------|
| `teams-for-linux` | Microsoft Teams client | CachyOS/Arch repos |
| `spotify-launcher` | Spotify launcher | Arch extra repos |
| `mailspring` | Beautiful email client | CachyOS repos |

### AUR Packages (paru)

| Package | Description | Votes |
|---------|-------------|-------|
| `slack-desktop` | Official Slack desktop client | 629+ |
| `outlook-for-linux-bin` | Unofficial Outlook client | 4+ |
| `ghostty` | Modern terminal emulator | - |
| `cursor-bin` | AI code editor | - |
| `vivaldi` | Vivaldi browser | - |

## 🔄 Updating

All packages can be updated using the `systemupdate` alias:

```bash
systemupdate
```

This will update both official packages (pacman) and AUR packages (paru).

## 🎯 Usage

After installation, launch applications:

```bash
# Communication
slack
teams-for-linux
outlook-for-linux  # Work email
mailspring         # Private email

# Development
ghostty
cursor

# Browser
vivaldi

# Media
spotify-launcher
```

## 🐧 Platform Support

Currently supported:
- ✅ CachyOS
- ✅ Arch Linux
- ✅ EndeavourOS
- ✅ Manjaro

Other distributions (Ubuntu, Fedora, etc.) are not yet supported but can be added.

## 🔧 Troubleshooting

### Slack/Teams not starting

Check if the application is installed:
```bash
pacman -Q slack-desktop teams-for-linux
```

### Cursor not found

Make sure cursor-bin is installed from AUR:
```bash
paru -Q cursor-bin
```

### Spotify launcher issues

Try running directly:
```bash
spotify-launcher
```

Check logs:
```bash
journalctl --user -u spotify-launcher -f
```

## 📚 Additional Resources

- [Slack AUR Package](https://aur.archlinux.org/packages/slack-desktop)
- [Teams for Linux GitHub](https://github.com/IsmaelMartinez/teams-for-linux)
- [Ghostty Website](https://ghostty.org/)
- [Cursor Website](https://cursor.sh/)
- [Vivaldi Linux](https://vivaldi.com/linux/)

## 🔐 Security Notes

### SSH Configuration
This work suite pairs well with the SSH setup in `linux/security/`:
- SSH daemon on port 27789
- Access only via LAN and Tailscale
- Firewall configured with UFW

### Flatpak Alternative

If you prefer sandboxed applications, you can use Flatpak versions:

```bash
# Slack
flatpak install flathub com.slack.Slack

# Spotify
flatpak install flathub com.spotify.Client
```

Note: Flatpak versions have better security isolation but may have slightly worse system integration.

## 📋 Checklist

- [ ] Install work suite packages
- [ ] Configure Slack workspace
- [ ] Sign in to Microsoft Teams
- [ ] Configure Outlook (work email)
- [ ] Configure Mailspring (private email)
- [ ] Set up Ghostty preferences
- [ ] Install Cursor extensions
- [ ] Configure Vivaldi sync
- [ ] Log in to Spotify

## 🤝 Contributing

To add more applications to the work suite:

1. Edit `install-worksuite.sh`
2. Add package to `OFFICIAL_PACKAGES` or `AUR_PACKAGES`
3. Update this README
4. Test installation

## 📄 License

Part of the dotfiles repository. See main README for license information.

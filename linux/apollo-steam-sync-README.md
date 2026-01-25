# Sunshine Steam Sync

Automatic synchronization of Steam games to Sunshine for game streaming.

**Note:** The script is named `apollo-steam-sync` for backward compatibility, but it works with Sunshine.

## ✨ Features

- 🎮 **Auto-detect** all installed Steam games
- 🖼️ **Auto-download** cover images from Steam CDN (auto-converts to PNG)
- 🔄 **Auto-sync** every hour (systemd timer)
- 🧹 **Auto-cleanup** removed games
- 🚫 **Smart filtering** - Skips Proton, runtimes, redistributables
- 📚 **Multi-library support** - Works with multiple Steam library folders
- 💾 **Backup** - Always backs up before making changes

## 🚀 Quick Start

### Aliases (Recommended)

```bash
# Sunshine aliases
sunsync        # Full sync + download covers + restart Sunshine
sungames       # List installed games
sunfix         # Fix missing/wrong covers interactively
sunlaunch      # Set game launch mode (normal/bigpicture/gamepadui)
sunstatus      # Check Sunshine status
sunrestart     # Restart Sunshine
sunlog         # View Sunshine logs

# Legacy aliases (also work)
apollosync     # Same as sunsync
apollogames    # Same as sungames
```

### Full Commands

```bash
# Full sync (apply changes + download covers)
apollo-steam-sync

# Preview only (dry run, no changes)
apollo-steam-sync --preview

# Skip cover downloads (faster)
apollo-steam-sync --no-covers

# List games
apollo-steam-sync --list

# Fix missing/wrong covers (interactive)
apollo-steam-sync --fix-cover

# Set game launch mode (interactive)
apollo-steam-sync --launch-mode
```

## ⚙️ Auto-Sync

Auto-sync is enabled by default and runs:
- **Every hour** to catch newly installed games
- **5 minutes after boot**

### Control Auto-Sync

```bash
# Check status
systemctl --user status sunshine-steam-sync.timer

# Stop auto-sync
systemctl --user stop sunshine-steam-sync.timer
systemctl --user disable sunshine-steam-sync.timer

# Start auto-sync
systemctl --user start sunshine-steam-sync.timer
systemctl --user enable sunshine-steam-sync.timer

# Run manually
systemctl --user start sunshine-steam-sync.service
```

## 📋 How It Works

1. **Scans** all Steam library folders for `appmanifest_*.acf` files
2. **Parses** game info (App ID, name, install directory)
3. **Filters** out non-games (Proton, runtimes, tools)
4. **Generates** Sunshine app entries with correct Steam launch URLs
5. **Merges** with existing Sunshine apps (preserves Desktop, custom apps)
6. **Saves** to `~/.config/sunshine/apps.json`
7. **Backs up** old config to `.json.backup`

## 🎮 Game Entry Format

Each Steam game is added as:

```json
{
    "name": "Game Name",
    "detached": ["setsid steam steam://rungameid/123456"],
    "image-path": "/home/christian/.config/sunshine/covers/123456.png",
    "virtual-display": true,
    "_steam_appid": "123456"
}
```

The `_steam_appid` field tracks which entries are managed by the sync tool.

**Important:** Cover images must be:
- PNG format (not JPG)
- Absolute paths (not relative)
- The script automatically handles JPG→PNG conversion

## 🔍 What Gets Filtered Out

- **Redistributables** (appid < 100,000)
- **Proton** versions (1,000,000 - 4,000,000)
- **Steam Linux Runtime** (1,000,000 - 4,000,000)
- **Tools** and **DLC** (by name matching)

## 📁 Files

| File | Purpose |
|------|---------|
| `~/.local/bin/apollo-steam-sync` | Main sync script (works with Sunshine) |
| `~/.config/sunshine/apps.json` | Sunshine apps config |
| `~/.config/sunshine/apps.json.backup` | Backup before sync |
| `~/.config/sunshine/covers/*.png` | Downloaded game covers (PNG format) |
| `~/.config/systemd/user/sunshine-steam-sync.service` | Sync service |
| `~/.config/systemd/user/sunshine-steam-sync.timer` | Auto-sync timer |

## 🐛 Troubleshooting

### No games showing up?

Check if you have actual games installed (not just Proton/runtimes):

```bash
apollogames
```

If empty, install some Steam games first!

### Games not launching?

1. Check Sunshine logs:
```bash
sunlog
# or legacy alias:
apollolog
```

2. Verify Steam is installed:
```bash
which steam
```

3. Test launching manually:
```bash
steam steam://rungameid/YOUR_APP_ID
```

### Wrong or missing cover?

Use the interactive cover fix tool:

```bash
apollofix
```

This will:
1. List all your games with cover status
2. Let you select which game to fix
3. Open Steam search to find correct App ID
4. Download and apply the correct cover

### Want to change how a game launches?

Use the interactive launch mode selector:

```bash
apollolaunch
```

Choose from:
- **🖥️ Normal** - Standard Steam launch
- **🎮 Big Picture** - Launch in Big Picture Mode (great for TV/couch gaming) **[DEFAULT]**
- **🕹️ Gamepad UI** - Launch in Steam Deck UI (perfect for Steam Deck streaming)

You can:
- Change a single game's launch mode
- Type `all` to set all games to the same mode at once

Perfect for when you stream from different devices (laptop vs Steam Deck)!

**Note:** Desktop and Steam Big Picture entries are never modified by the sync tool.

### Need to restore backup?

```bash
cp ~/.config/sunshine/apps.json.backup ~/.config/sunshine/apps.json
systemctl --user restart sunshine
```

## 🎮 Display Configuration

After migration to Sunshine, use the display setup script to configure which output Sunshine uses:

```bash
sunshine-display-setup
```

This will:
- Detect all connected displays (DP and HDMI)
- Configure Sunshine to use HDMI for streaming
- Provide instructions for hiding HDMI from Gnome desktop

This ensures Sunshine streams from HDMI while Gnome desktop only uses DP outputs.

## 🔧 Advanced Usage

### Custom Steam library locations

The script automatically detects all Steam library folders from:
```
~/.steam/steam/steamapps/libraryfolders.vdf
```

### Modify filtering

Edit `/home/christian/.local/bin/apollo-steam-sync` and adjust:

```python
# Skip common non-game entries by name
skip_names = [
    "proton",
    "runtime",
    "redistributable",
    # Add more here...
]
```

### Change sync frequency

Edit timer:
```bash
systemctl --user edit apollo-steam-sync.timer
```

## 📝 Example Workflow

1. **Install new Steam game**
2. **Wait 1 hour** (or run `apollosync`)
3. **Open Moonlight** on client device
4. **Game appears with cover** in Apollo game list
5. **Launch and play!** 🎮

---

**Made with ❤️ for seamless game streaming**

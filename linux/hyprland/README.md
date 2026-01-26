# Hyprland Setup for Sunshine Streaming

**Complete Hyprland configuration for headless game streaming with proper display management.**

## 📁 Files

- `HYPRLAND-MIGRATION.md` - Complete migration guide with all details
- `hyprland.conf` - Main Hyprland configuration
- `sunshine.conf` - Sunshine configuration for Hyprland
- `backup-before-install.sh` - Backup script (run BEFORE reinstall)
- `restore-after-install.sh` - Restore script (run AFTER fresh install)
- `install-hyprland.sh` - Hyprland installation script

## 🚀 Quick Start

### Before Reinstall

```bash
# 1. Backup everything
cd ~/.config/dotfiles/linux/hyprland
./backup-before-install.sh

# 2. Copy backup to external storage
cp -r ~/hyprland-migration-backup /path/to/usb/

# 3. Push dotfiles to git
cd ~/.config/dotfiles
git add -A
git commit -m "Pre-Hyprland migration backup"
git push
```

### After Fresh Install

```bash
# 1. Install base system (git, base-devel, etc.)
sudo pacman -Syu git base-devel

# 2. Clone dotfiles
cd ~/.config
git clone <your-repo> dotfiles

# 3. Copy backup from external storage
cp -r /path/to/usb/hyprland-migration-backup ~/

# 4. Restore system configs
cd ~/.config/dotfiles/linux/hyprland
./restore-after-install.sh

# 5. Install Hyprland
./install-hyprland.sh

# 6. Reboot and select Hyprland
sudo reboot
```

## ✅ Why Hyprland Fixes Display Issues

### Gnome Problems:
- ❌ Ignores `monitors.xml` randomly
- ❌ Makes HDMI primary despite config
- ❌ Complex XML configs that don't always work
- ❌ Session isolation issues with Sunshine

### Hyprland Solutions:
- ✅ Simple text config that ALWAYS works
- ✅ `monitor=HDMI-A-1,disable` keeps HDMI away from desktop
- ✅ Sunshine can still capture disabled HDMI output
- ✅ No session isolation issues
- ✅ Better gaming performance

## 🎮 Sunshine Configuration

Hyprland config disables HDMI from desktop but keeps it available for Sunshine:

```ini
# In hyprland.conf:
monitor=HDMI-A-1,1920x1080@60,7680x0,1
exec-once = hyprctl keyword monitor HDMI-A-1,disable
```

Sunshine captures the disabled HDMI:

```ini
# In sunshine.conf:
output_name = HDMI-A-1
capture = kms
```

**This gives you:**
- ✅ HDMI never shows up on desktop
- ✅ Sunshine streams from HDMI
- ✅ DP displays work normally
- ✅ No "HDMI becomes primary" issues

## 📖 More Info

See `HYPRLAND-MIGRATION.md` for complete documentation.

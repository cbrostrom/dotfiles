# Current System Snapshot (Pre-Hyprland)

**Date:** 2026-01-26  
**System:** CachyOS (Arch-based)  
**Desktop:** Gnome 49.3 (Wayland)  
**Total Packages:** 297 explicitly installed

---

## 🖥️ Desktop Environment

### Gnome (Wayland)
```
gdm 49.2-1.1                           # Display manager
gnome-shell 1:49.3-1.1                 # Desktop shell
gnome-control-center 49.3-1.1          # Settings
gnome-session 49.2-1.1                 # Session manager
gnome-settings-daemon 49.1-1.1         # Background daemon
mutter (via gnome-shell)               # Compositor
```

**Installed:** 21 jan 2026

### Gnome Extensions
```
gnome-shell-extension-appindicator 1:61-1
gnome-shell-extension-caffeine 59-1
gnome-shell-extensions 49.0-1
```

### Gnome Apps
```
gnome-terminal 3.58.1-1.1
gnome-console 49.2-1.1
gnome-tweaks 49.0-2
gnome-system-monitor 49.1-1.1
gnome-disk-utility 46.1-2.1
gnome-calculator 49.2-1.1
gnome-calendar 49.1-1.1
gnome-clocks 49.0-1.1
gnome-maps 49.3-1.1
gnome-music 1:49.1-2
gnome-weather 49.0-1
```

---

## 🎮 Gaming & Streaming

### Core Gaming
```
cachyos-gaming-meta 1:1.0.0-6          # CachyOS gaming metapackage
cachyos-gaming-applications 1.0.0-2    # Gaming tools
steamtinkerlaunch 12.12-1              # Steam game tweaker
protonup-qt 2.14.0-2                   # Proton version manager
```

### Graphics (NVIDIA)
```
nvidia-580xx-dkms 580.126.09-1         # NVIDIA driver
nvidia-settings 590.48.01-2            # NVIDIA control panel
libva-nvidia-driver 0.0.14-1.1         # Hardware video acceleration
cuda 13.1.1-1                          # CUDA toolkit (for NVENC)
vulkan-icd-loader 1.4.335.0-1.1        # Vulkan support
lib32-vulkan-icd-loader 1.4.335.0-1    # 32-bit Vulkan
```

### Streaming
```
sunshine 2025.924.154138-3             # Game streaming host
```

**Sunshine installed:** 25 jan 2026

---

## 💻 Applications

### Development
```
cursor-bin 2.4.21-1                    # Cursor IDE
```

### Communication
```
discord 1:0.0.121-1                    # Discord
```

### Productivity
```
bitwarden 2025.10.0-1.1                # Password manager
```

### Media
```
spotify 1:1.2.79.427-1                 # Music streaming
```

### Browser
```
firefoxpwa 2.18.0-1.3                  # Firefox PWA support
```

---

## 🛠️ System Tools

### CachyOS Specific
```
cachyos-hello 0.19.2-1                 # Welcome app
cachyos-kernel-manager 1.16.1-1.1      # Kernel manager
cachyos-packageinstaller 1.5.1-2       # Package installer GUI
cachy-update 3.17.7-1                  # Update manager
cachyos-settings 1:1.3.0-1             # System settings
cachyos-hooks 2025.09.22-1             # System hooks
cachyos-rate-mirrors 18-1              # Mirror ranking
bpftune-git r743.5862aed-1             # BPF auto-tuning
```

### Monitoring
```
btop 1.4.6-1.1                         # System monitor
bottom 0.12.3-1.1                      # Process viewer
```

### Audio
```
bluez 5.85-1.1                         # Bluetooth stack
bluez-utils 5.85-1.1                   # Bluetooth tools
alsa-utils 1.2.15.2-1.1                # ALSA utilities
alsa-plugins 1:1.2.12-5.1              # ALSA plugins
```

### Network
```
bind 9.20.18-1.1                       # DNS tools
bridge-utils 1.7.1-3.1                 # Network bridging
```

### Music Management
```
beets 2.5.1-4                          # Music library manager
```

---

## 💾 Storage Configuration

### Local Drives (NTFS)
```
/mnt/software     # Software storage
/mnt/storage      # Main storage (7.3TB) - also shared via Samba
/mnt/games/fast   # Fast games SSD
/mnt/games/main   # Main games drive
/mnt/games/extra  # Extra games storage
/mnt/cos          # COS partition
```

### Network Mounts (Samba/CIFS - linuxbro server)
```
/mnt/linuxbro/movies
/mnt/linuxbro/storage
/mnt/linuxbro/downloads
/mnt/linuxbro/music
/mnt/linuxbro/media
/mnt/linuxbro/dropbox
/mnt/linuxbro/christian
```

**All configured in `/etc/fstab` with systemd automount**

### Samba Server
```
Shares: [Storage] (/mnt/storage)
Access: VM network only (192.168.122.0/24)
Security: User-based (christian), no guest
```

---

## 🔧 Shell & Terminal

### Shell
```
zsh (via cachyos-zsh-config 1.0.3-1)
fnm (Fast Node Manager) for Node.js
direnv for project environments
```

### Terminal Tools
```
awesome-terminal-fonts 1.1.0-5
bash-completion 2.17.0-3
```

---

## 📦 Package Management

```
base 3-2
base-devel 1-2
cachyos-keyring 20240331-1
cachyos-mirrorlist 22-1
```

---

## 🎯 Critical Files to Preserve

### System Configs
```
/etc/fstab                              # All mounts
/etc/samba/credentials-linuxbro         # Samba credentials
/etc/samba/smb.conf                     # Samba server config
/etc/gdm/custom.conf                    # GDM/autologin settings
```

### User Configs (in dotfiles)
```
~/.zshrc                                # Shell config
~/.gitconfig                            # Git config
~/.config/starship.toml                 # Prompt
~/.config/cursor/                       # Cursor settings
~/.config/sunshine/                     # Sunshine config
~/.config/gnome/                        # Gnome settings (dconf)
```

### Gaming Configs (in dotfiles)
```
~/dotfiles/gaming/dxvk-configs/         # DXVK configs
~/dotfiles/gaming/bin/                  # Game launch scripts
```

---

## 📊 System Stats

- **Total Packages:** 297 explicitly installed
- **Desktop:** Gnome 49.3 (Wayland)
- **Kernel:** CachyOS optimized
- **GPU:** NVIDIA (driver 580.126.09)
- **Storage:** 6 local drives + 7 network mounts
- **Gaming:** Steam + Proton + Sunshine streaming

---

## 🚀 Migration Notes

This snapshot documents the current system before Hyprland migration.

**Backup script location:** `linux/hyprland/backup-before-install.sh`

**What gets backed up:**
- All system configs (fstab, Samba, etc.)
- Network settings
- Package lists (pacman + AUR)
- Systemd services
- Sunshine config

**Restore script location:** `linux/hyprland/restore-after-install.sh`

---

**Snapshot created:** 2026-01-26  
**Ready for Hyprland migration!** 🎯

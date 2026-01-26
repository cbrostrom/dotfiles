# Hyprland Migration Guide

**Complete guide to migrate from Gnome to Hyprland while preserving all critical configs.**

## 📋 Critical Configs to Preserve

### 1. **Storage Mounts (CRITICAL)**

Your `/etc/fstab` contains:
- **Local NTFS drives:**
  - `/mnt/software` - Software storage
  - `/mnt/storage` - Main storage (7.3TB)
  - `/mnt/games/fast` - Fast games SSD
  - `/mnt/games/main` - Main games drive
  - `/mnt/games/extra` - Extra games storage
  - `/mnt/cos` - COS partition

- **Samba/CIFS network mounts (linuxbro server):**
  - `/mnt/linuxbro/movies`
  - `/mnt/linuxbro/storage`
  - `/mnt/linuxbro/downloads`
  - `/mnt/linuxbro/music`
  - `/mnt/linuxbro/media`
  - `/mnt/linuxbro/dropbox`
  - `/mnt/linuxbro/christian`

**All mounts use systemd automount with network-online.target dependency.**

### 2. **Samba Credentials**

Location: `/etc/samba/credentials-linuxbro`

**BACKUP THIS FILE BEFORE REINSTALL!**

### 3. **Samba Server Config**

Location: `/etc/samba/smb.conf`

- Only allows VM network (192.168.122.0/24)
- Shares `/mnt/storage` as `[Storage]`
- Security: user-based, no guest access

### 4. **Gaming Configs**

All preserved in your dotfiles:
- DXVK configs for Diablo 4, Last Epoch
- Game launch scripts
- Shader cache optimizations

---

## 🚀 Fresh Install Steps

### **Before Reinstall (Backup)**

```bash
# 1. Backup critical system configs
sudo cp /etc/fstab ~/fstab.backup
sudo cp /etc/samba/credentials-linuxbro ~/credentials-linuxbro.backup
sudo cp /etc/samba/smb.conf ~/smb.conf.backup

# 2. Your dotfiles are already in git, so just push
cd ~/.config/dotfiles
git add -A
git commit -m "Pre-Hyprland migration backup"
git push

# 3. Note down your network settings if static IP
ip addr
ip route
```

### **After Fresh Install**

#### **1. Install Base System**

```bash
# Update system
sudo pacman -Syu

# Install essential tools
sudo pacman -S git base-devel vim networkmanager

# Enable NetworkManager
sudo systemctl enable --now NetworkManager
```

#### **2. Restore Dotfiles**

```bash
# Clone dotfiles
cd ~/.config
git clone <your-dotfiles-repo> dotfiles
cd dotfiles

# Run install script (if you have one)
./install.sh
```

#### **3. Restore Storage Mounts**

```bash
# Create mount directories
sudo mkdir -p /mnt/{software,storage,games/{fast,main,extra},cos}
sudo mkdir -p /mnt/linuxbro/{movies,storage,downloads,music,media,dropbox,christian}

# Restore fstab
sudo cp ~/fstab.backup /etc/fstab

# Restore Samba credentials
sudo cp ~/credentials-linuxbro.backup /etc/samba/credentials-linuxbro
sudo chmod 600 /etc/samba/credentials-linuxbro
sudo chown root:root /etc/samba/credentials-linuxbro

# Test mounts
sudo systemctl daemon-reload
sudo mount -a

# Verify
df -h | grep mnt
```

#### **4. Restore Samba Server (if needed)**

```bash
# Install Samba
sudo pacman -S samba

# Restore config
sudo cp ~/smb.conf.backup /etc/samba/smb.conf

# Set Samba password
sudo smbpasswd -a christian

# Enable Samba
sudo systemctl enable --now smb nmb
```

#### **5. Install Hyprland**

```bash
# Install Hyprland + essentials
sudo pacman -S hyprland xdg-desktop-portal-hyprland \
    kitty waybar wofi polkit-kde-agent \
    qt5-wayland qt6-wayland

# Install additional tools
sudo pacman -S brightnessctl playerctl grim slurp \
    wl-clipboard cliphist swaylock swayidle \
    network-manager-applet blueman pavucontrol
```

#### **6. Install Sunshine**

```bash
# Install Sunshine
sudo pacman -S sunshine

# Enable user service
systemctl --user enable sunshine.service

# Restore CUDA drop-in
mkdir -p ~/.config/systemd/user/sunshine.service.d/
cp ~/.config/dotfiles/linux/sunshine-cuda.conf \
   ~/.config/systemd/user/sunshine.service.d/cuda.conf

systemctl --user daemon-reload
```

---

## 🎮 Hyprland Config for Your Setup

### **Display Configuration**

Create `~/.config/hypr/hyprland.conf`:

```ini
# Monitor setup
monitor=DP-1,3840x2160@144,0x0,1          # Primary 4K display
monitor=DP-2,3840x2160@144,3840x0,1       # Secondary 4K display (if you have 2)
monitor=HDMI-A-1,1920x1080@60,7680x0,1    # Sunshine dummy (disabled from desktop)

# CRITICAL: Disable HDMI from workspace assignment
workspace=1,monitor:DP-1,default:true
workspace=2,monitor:DP-1
workspace=3,monitor:DP-1

# HDMI is ONLY for Sunshine - never show workspaces here
exec-once = hyprctl keyword monitor HDMI-A-1,disable

# Auto-start essentials
exec-once = waybar
exec-once = /usr/lib/polkit-kde-authentication-agent-1
exec-once = nm-applet
exec-once = blueman-applet

# Sunshine
exec-once = systemctl --user start sunshine.service

# Environment for NVIDIA
env = LIBVA_DRIVER_NAME,nvidia
env = XDG_SESSION_TYPE,wayland
env = GBM_BACKEND,nvidia-drm
env = __GLX_VENDOR_LIBRARY_NAME,nvidia
env = WLR_NO_HARDWARE_CURSORS,1

# CUDA for Sunshine
env = LD_LIBRARY_PATH,/usr/lib:/opt/cuda/lib64
env = CUDA_VISIBLE_DEVICES,0

# Input
input {
    kb_layout = us,dk
    kb_options = grp:alt_shift_toggle
    
    follow_mouse = 1
    
    touchpad {
        natural_scroll = no
    }
    
    sensitivity = 0
}

# General
general {
    gaps_in = 5
    gaps_out = 10
    border_size = 2
    col.active_border = rgba(33ccffee) rgba(00ff99ee) 45deg
    col.inactive_border = rgba(595959aa)
    
    layout = dwindle
}

# Decoration
decoration {
    rounding = 5
    
    blur {
        enabled = true
        size = 3
        passes = 1
    }
    
    drop_shadow = yes
    shadow_range = 4
    shadow_render_power = 3
    col.shadow = rgba(1a1a1aee)
}

# Animations
animations {
    enabled = yes
    
    bezier = myBezier, 0.05, 0.9, 0.1, 1.05
    
    animation = windows, 1, 7, myBezier
    animation = windowsOut, 1, 7, default, popin 80%
    animation = border, 1, 10, default
    animation = borderangle, 1, 8, default
    animation = fade, 1, 7, default
    animation = workspaces, 1, 6, default
}

# Layouts
dwindle {
    pseudotile = yes
    preserve_split = yes
}

# Key bindings
$mainMod = SUPER

bind = $mainMod, Return, exec, kitty
bind = $mainMod, Q, killactive,
bind = $mainMod, M, exit,
bind = $mainMod, E, exec, dolphin
bind = $mainMod, V, togglefloating,
bind = $mainMod, R, exec, wofi --show drun
bind = $mainMod, P, pseudo,
bind = $mainMod, J, togglesplit,

# Move focus
bind = $mainMod, left, movefocus, l
bind = $mainMod, right, movefocus, r
bind = $mainMod, up, movefocus, u
bind = $mainMod, down, movefocus, d

# Switch workspaces
bind = $mainMod, 1, workspace, 1
bind = $mainMod, 2, workspace, 2
bind = $mainMod, 3, workspace, 3
bind = $mainMod, 4, workspace, 4
bind = $mainMod, 5, workspace, 5
bind = $mainMod, 6, workspace, 6
bind = $mainMod, 7, workspace, 7
bind = $mainMod, 8, workspace, 8
bind = $mainMod, 9, workspace, 9
bind = $mainMod, 0, workspace, 10

# Move window to workspace
bind = $mainMod SHIFT, 1, movetoworkspace, 1
bind = $mainMod SHIFT, 2, movetoworkspace, 2
bind = $mainMod SHIFT, 3, movetoworkspace, 3
bind = $mainMod SHIFT, 4, movetoworkspace, 4
bind = $mainMod SHIFT, 5, movetoworkspace, 5
bind = $mainMod SHIFT, 6, movetoworkspace, 6
bind = $mainMod SHIFT, 7, movetoworkspace, 7
bind = $mainMod SHIFT, 8, movetoworkspace, 8
bind = $mainMod SHIFT, 9, movetoworkspace, 9
bind = $mainMod SHIFT, 0, movetoworkspace, 10

# Scroll through workspaces
bind = $mainMod, mouse_down, workspace, e+1
bind = $mainMod, mouse_up, workspace, e-1

# Move/resize windows
bindm = $mainMod, mouse:272, movewindow
bindm = $mainMod, mouse:273, resizewindow

# Media keys
bind = , XF86AudioRaiseVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+
bind = , XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-
bind = , XF86AudioMute, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
bind = , XF86AudioPlay, exec, playerctl play-pause
bind = , XF86AudioNext, exec, playerctl next
bind = , XF86AudioPrev, exec, playerctl previous

# Screenshot
bind = , Print, exec, grim -g "$(slurp)" - | wl-copy
bind = SHIFT, Print, exec, grim - | wl-copy

# Lock screen
bind = $mainMod, L, exec, swaylock
```

---

## 🎯 Sunshine Configuration for Hyprland

Create `~/.config/sunshine/sunshine.conf`:

```ini
# GPU
adapter_name = /dev/dri/card1
encoder = nvenc

# Display - Hyprland will ALWAYS respect this
output_name = HDMI-A-1

# Capture - use KMS for Hyprland
capture = kms

# Video
hevc_mode = 1
av1_mode = 1
nvenc_preset = 1
nvenc_twopass = disabled
qp = 32

# Audio
audio_sink = auto

# Network
port = 47989
sunshine_name = MonsterBro
upnp = on

# Performance
min_threads = 1
fec_percentage = 5

# Logging
min_log_level = warning
```

---

## ✅ Post-Install Checklist

```bash
# 1. Verify all mounts
df -h | grep mnt

# 2. Test network mounts
ls /mnt/linuxbro/movies

# 3. Test Samba server (if needed)
smbclient -L localhost -U christian

# 4. Test Sunshine
systemctl --user status sunshine
curl http://localhost:47989

# 5. Test Moonlight connection
# Connect from client device

# 6. Verify gaming setup
ls ~/.config/dotfiles/gaming/
```

---

## 🎮 Why Hyprland Will Fix Your Issues

### **Display Management:**
- ✅ `monitor=` config is **ALWAYS respected**
- ✅ No "Gnome decides HDMI is primary" bullshit
- ✅ HDMI can be disabled from desktop but still available for Sunshine
- ✅ Simple config files - no complex XML

### **Sunshine:**
- ✅ Autostart via `exec-once` or systemd user service
- ✅ KMS capture works perfectly on Wayland
- ✅ No session isolation issues
- ✅ Portal integration is clean

### **Performance:**
- ✅ Lower overhead than Gnome
- ✅ Better gaming performance
- ✅ Direct compositor control

---

## 📝 Additional Notes

### **Noctalia Shell (Optional)**

If you want Noctalia on top of Hyprland:

```bash
# Install Quickshell first
paru -S quickshell-git

# Then install Noctalia
# Follow Noctalia installation instructions
```

### **Your Dotfiles Structure**

Keep your current dotfiles structure:
```
~/.config/dotfiles/
├── gaming/           # All gaming configs (preserved)
├── linux/
│   ├── hyprland/    # NEW: Hyprland configs
│   ├── gnome/       # Keep for reference
│   └── ...
├── .zshrc
└── ...
```

### **Migration Script**

Want me to create a `migrate-to-hyprland.sh` script that automates all of this?

---

## 🆘 Troubleshooting

### **Mounts not working:**
```bash
# Check systemd mount units
systemctl list-units --type=mount --all

# Manually mount to test
sudo mount /mnt/linuxbro/movies
```

### **Samba credentials:**
```bash
# Verify credentials file
sudo cat /etc/samba/credentials-linuxbro
# Should contain:
# username=youruser
# password=yourpass
```

### **Sunshine not starting:**
```bash
# Check logs
journalctl --user -u sunshine -f

# Manually start
systemctl --user start sunshine
```

---

**Ready for tomorrow's fresh install! 🚀**

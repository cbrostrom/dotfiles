#!/bin/bash

# Hyprland installation script for CachyOS
# This script installs Hyprland and all necessary components

set -e

echo "=== Hyprland Installation Script ==="
echo ""

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    echo "ERROR: Do not run this script as root!"
    exit 1
fi

echo "1. Installing Hyprland and core components..."
sudo pacman -S --needed --noconfirm \
    hyprland \
    xdg-desktop-portal-hyprland \
    qt5-wayland \
    qt6-wayland \
    polkit-kde-agent

echo ""
echo "2. Installing essential tools..."
sudo pacman -S --needed --noconfirm \
    kitty \
    waybar \
    wofi \
    dolphin \
    brightnessctl \
    playerctl \
    grim \
    slurp \
    wl-clipboard \
    cliphist \
    swaylock \
    swayidle \
    network-manager-applet \
    blueman \
    pavucontrol

echo ""
echo "3. Installing fonts..."
sudo pacman -S --needed --noconfirm \
    ttf-font-awesome \
    ttf-fira-code \
    noto-fonts \
    noto-fonts-emoji

echo ""
echo "4. Creating Hyprland config directory..."
mkdir -p ~/.config/hypr

echo ""
echo "5. Copying Hyprland config..."
cp ~/.config/dotfiles/linux/hyprland/hyprland.conf ~/.config/hypr/

echo ""
echo "6. Copying Sunshine config..."
mkdir -p ~/.config/sunshine
cp ~/.config/dotfiles/linux/hyprland/sunshine.conf ~/.config/sunshine/

echo ""
echo "7. Setting up Sunshine service..."
mkdir -p ~/.config/systemd/user/sunshine.service.d/

cat > ~/.config/systemd/user/sunshine.service.d/cuda.conf <<EOF
[Service]
# Add CUDA libraries to LD_LIBRARY_PATH for NVENC hardware encoding
Environment="LD_LIBRARY_PATH=/usr/lib:/opt/cuda/lib64:\$LD_LIBRARY_PATH"
Environment="CUDA_VISIBLE_DEVICES=0"
EOF

systemctl --user daemon-reload
systemctl --user enable sunshine.service

echo ""
echo "8. Installing additional gaming tools..."
sudo pacman -S --needed --noconfirm \
    gamemode \
    lib32-gamemode \
    mangohud \
    lib32-mangohud

echo ""
echo "=== Installation Complete! ==="
echo ""
echo "Next steps:"
echo "1. Reboot your system"
echo "2. Select 'Hyprland' from your display manager (GDM/SDDM)"
echo "3. Log in"
echo "4. Test Sunshine streaming"
echo ""
echo "Key bindings:"
echo "  Super + Return     - Open terminal (kitty)"
echo "  Super + R          - Open app launcher (wofi)"
echo "  Super + E          - Open file manager (dolphin)"
echo "  Super + Q          - Close window"
echo "  Super + M          - Exit Hyprland"
echo "  Super + L          - Lock screen"
echo "  Super + 1-9        - Switch workspace"
echo "  Super + Shift + 1-9 - Move window to workspace"
echo ""
echo "To customize:"
echo "  Edit ~/.config/hypr/hyprland.conf"
echo "  Edit ~/.config/sunshine/sunshine.conf"
echo ""

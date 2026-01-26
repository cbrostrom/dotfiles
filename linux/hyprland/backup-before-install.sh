#!/bin/bash

# Backup critical system configs before Hyprland migration
# Run this BEFORE reinstalling your system

set -e

BACKUP_DIR=~/hyprland-migration-backup
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

echo "=== Hyprland Migration Backup Script ==="
echo "Backup location: $BACKUP_DIR"
echo ""

# Create backup directory
mkdir -p "$BACKUP_DIR"

echo "1. Backing up fstab..."
sudo cp /etc/fstab "$BACKUP_DIR/fstab.backup.$TIMESTAMP"

echo "2. Backing up Samba credentials..."
if [ -f /etc/samba/credentials-linuxbro ]; then
    sudo cp /etc/samba/credentials-linuxbro "$BACKUP_DIR/credentials-linuxbro.backup.$TIMESTAMP"
else
    echo "   WARNING: /etc/samba/credentials-linuxbro not found!"
fi

echo "3. Backing up Samba config..."
if [ -f /etc/samba/smb.conf ]; then
    sudo cp /etc/samba/smb.conf "$BACKUP_DIR/smb.conf.backup.$TIMESTAMP"
else
    echo "   WARNING: /etc/samba/smb.conf not found!"
fi

echo "4. Backing up network config..."
ip addr > "$BACKUP_DIR/network-config.$TIMESTAMP.txt"
ip route >> "$BACKUP_DIR/network-config.$TIMESTAMP.txt"

echo "5. Backing up pacman package list..."
pacman -Qqe > "$BACKUP_DIR/pacman-packages.$TIMESTAMP.txt"

echo "6. Backing up AUR package list..."
if command -v paru &> /dev/null; then
    paru -Qqm > "$BACKUP_DIR/aur-packages.$TIMESTAMP.txt"
fi

echo "7. Listing systemd services..."
systemctl list-unit-files --state=enabled > "$BACKUP_DIR/systemd-services.$TIMESTAMP.txt"
systemctl --user list-unit-files --state=enabled > "$BACKUP_DIR/systemd-user-services.$TIMESTAMP.txt"

echo "8. Backing up Sunshine config..."
if [ -f ~/.config/sunshine/sunshine.conf ]; then
    cp ~/.config/sunshine/sunshine.conf "$BACKUP_DIR/sunshine.conf.backup.$TIMESTAMP"
fi

echo "9. Making backup directory accessible by root..."
sudo chown -R $(whoami):$(whoami) "$BACKUP_DIR"
sudo chmod -R 600 "$BACKUP_DIR"/*backup*

echo ""
echo "=== Backup Complete! ==="
echo ""
echo "Backup location: $BACKUP_DIR"
echo ""
echo "IMPORTANT: Copy this backup to external storage or USB drive!"
echo ""
echo "Files backed up:"
ls -lh "$BACKUP_DIR"
echo ""
echo "Next steps:"
echo "1. Copy $BACKUP_DIR to external storage"
echo "2. Push your dotfiles to git:"
echo "   cd ~/.config/dotfiles"
echo "   git add -A"
echo "   git commit -m 'Pre-Hyprland migration backup'"
echo "   git push"
echo "3. Boot from live USB and reinstall"
echo "4. After reinstall, restore from backup using restore-after-install.sh"
echo ""

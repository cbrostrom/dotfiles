#!/bin/bash

# Restore critical system configs after fresh install
# Run this AFTER fresh system install

set -e

BACKUP_DIR=~/hyprland-migration-backup

echo "=== Hyprland Migration Restore Script ==="
echo ""

# Check if backup directory exists
if [ ! -d "$BACKUP_DIR" ]; then
    echo "ERROR: Backup directory not found: $BACKUP_DIR"
    echo "Please copy your backup to this location first!"
    exit 1
fi

echo "Found backup directory: $BACKUP_DIR"
echo ""

# Find latest backup files
FSTAB_BACKUP=$(ls -t "$BACKUP_DIR"/fstab.backup.* 2>/dev/null | head -1)
CREDS_BACKUP=$(ls -t "$BACKUP_DIR"/credentials-linuxbro.backup.* 2>/dev/null | head -1)
SMB_BACKUP=$(ls -t "$BACKUP_DIR"/smb.conf.backup.* 2>/dev/null | head -1)

echo "1. Creating mount directories..."
sudo mkdir -p /mnt/{software,storage,games/{fast,main,extra},cos}
sudo mkdir -p /mnt/linuxbro/{movies,storage,downloads,music,media,dropbox,christian}

echo "2. Restoring fstab..."
if [ -f "$FSTAB_BACKUP" ]; then
    sudo cp "$FSTAB_BACKUP" /etc/fstab
    echo "   ✓ fstab restored"
else
    echo "   ✗ fstab backup not found!"
fi

echo "3. Restoring Samba credentials..."
if [ -f "$CREDS_BACKUP" ]; then
    sudo cp "$CREDS_BACKUP" /etc/samba/credentials-linuxbro
    sudo chmod 600 /etc/samba/credentials-linuxbro
    sudo chown root:root /etc/samba/credentials-linuxbro
    echo "   ✓ Samba credentials restored"
else
    echo "   ✗ Samba credentials backup not found!"
fi

echo "4. Restoring Samba config..."
if [ -f "$SMB_BACKUP" ]; then
    sudo cp "$SMB_BACKUP" /etc/samba/smb.conf
    echo "   ✓ Samba config restored"
else
    echo "   ✗ Samba config backup not found!"
fi

echo "5. Reloading systemd and mounting drives..."
sudo systemctl daemon-reload
sudo mount -a

echo ""
echo "6. Verifying mounts..."
df -h | grep mnt || echo "   ✗ No mounts found!"

echo ""
echo "=== Restore Complete! ==="
echo ""
echo "Next steps:"
echo "1. Verify mounts: df -h | grep mnt"
echo "2. Test network mounts: ls /mnt/linuxbro/movies"
echo "3. If Samba server needed:"
echo "   sudo pacman -S samba"
echo "   sudo smbpasswd -a christian"
echo "   sudo systemctl enable --now smb nmb"
echo "4. Install Hyprland:"
echo "   cd ~/.config/dotfiles/linux/hyprland"
echo "   ./install-hyprland.sh"
echo ""

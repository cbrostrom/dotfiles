#!/bin/bash
#
# Setup LinuxBro Symlinks
# Creates convenient symlinks to LinuxBro media share subdirectories
#
# Usage: setup-linuxbro-symlinks.sh

set -e

LINUXBRO_BASE="/media/linuxbro"
SCRIPT_NAME="$(basename "$0")"

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}Setting up LinuxBro symlinks...${NC}"
echo ""

# Check if LinuxBro is mounted/accessible
if [[ ! -d "$LINUXBRO_BASE/4tb" ]]; then
    echo -e "${YELLOW}Warning: LinuxBro media share not accessible at $LINUXBRO_BASE${NC}"
    echo "Triggering automount by accessing the directory..."
    ls "$LINUXBRO_BASE" > /dev/null 2>&1 || true
    sleep 2
    
    if [[ ! -d "$LINUXBRO_BASE/4tb" ]]; then
        echo -e "${YELLOW}Error: Cannot access LinuxBro. Make sure:${NC}"
        echo "  1. LinuxBro (192.168.1.100) is online"
        echo "  2. SMB credentials are correct (~/.smb-credentials)"
        echo "  3. fstab entry is correct"
        exit 1
    fi
fi

# Function to create symlink safely
create_symlink() {
    local target="$1"
    local link="$2"
    local description="$3"
    
    # Check if target exists
    if [[ ! -e "$target" ]]; then
        echo -e "${YELLOW}⚠ Skipping: $description (target doesn't exist: $target)${NC}"
        return
    fi
    
    # Remove existing symlink if it exists
    if [[ -L "$link" ]]; then
        echo -e "  Removing old symlink: $link"
        rm "$link"
    elif [[ -e "$link" ]]; then
        echo -e "${YELLOW}⚠ Warning: $link exists but is not a symlink. Skipping.${NC}"
        return
    fi
    
    # Create parent directory if needed
    local parent_dir="$(dirname "$link")"
    if [[ ! -d "$parent_dir" ]]; then
        sudo mkdir -p "$parent_dir"
    fi
    
    # Create symlink
    sudo ln -s "$target" "$link"
    echo -e "${GREEN}✓ Created: $link → $target${NC}"
}

echo "Creating symlinks based on LinuxBro media structure..."
echo ""

# === DOWNLOADS ===
create_symlink "$LINUXBRO_BASE/4tb/Downloads" "/mnt/linuxbro/downloads" "Downloads"

# === MUSIC ===
create_symlink "$LINUXBRO_BASE/2tb/Music" "/mnt/linuxbro/music" "Music"

# === MOVIES ===
# Check if Movies is in 8tb or elsewhere
if [[ -d "$LINUXBRO_BASE/8tb/Movies" ]]; then
    create_symlink "$LINUXBRO_BASE/8tb/Movies" "/mnt/linuxbro/movies" "Movies"
elif [[ -d "$LINUXBRO_BASE/4tb/Movies" ]]; then
    create_symlink "$LINUXBRO_BASE/4tb/Movies" "/mnt/linuxbro/movies" "Movies"
fi

# === TV SHOWS ===
if [[ -d "$LINUXBRO_BASE/4tb/TV" ]]; then
    create_symlink "$LINUXBRO_BASE/4tb/TV" "/mnt/linuxbro/tv" "TV Shows"
fi

# === BOOKS ===
if [[ -d "$LINUXBRO_BASE/2tb/Books" ]]; then
    create_symlink "$LINUXBRO_BASE/2tb/Books" "/mnt/linuxbro/books" "Books"
fi

echo ""
echo -e "${GREEN}✓ LinuxBro symlinks setup complete!${NC}"
echo ""
echo "Available shortcuts in /mnt/linuxbro/:"
echo "  /mnt/linuxbro/downloads  → 4TB Downloads"
echo "  /mnt/linuxbro/music      → 2TB Music"
echo "  /mnt/linuxbro/movies     → Movies"
echo "  /mnt/linuxbro/tv         → TV Shows"
echo "  /mnt/linuxbro/books      → Books"
echo ""
echo "Main mount: /media/linuxbro (automounted)"
echo "Direct drive access: /media/linuxbro/{2tb,4tb,8tb}"
echo "To add more symlinks, edit: $HOME/.config/dotfiles/linux/setup-linuxbro-symlinks.sh"

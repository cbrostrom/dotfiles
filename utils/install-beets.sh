#!/usr/bin/env bash
# Install Beets and all required plugins/dependencies

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}═══════════════════════════════════════════════${NC}"
echo -e "${BLUE}  Beets Installation${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════${NC}"
echo ""

# Check if running Arch-based system
if ! command -v pacman &> /dev/null; then
    echo -e "${RED}Error: This script is for Arch-based systems${NC}"
    exit 1
fi

echo -e "${YELLOW}Packages to install:${NC}"
echo "  - beets (music library manager)"
echo "  - python-pyacoustid (audio fingerprinting)"
echo "  - python-pylast (Last.fm integration)"
echo "  - python-requests (API calls)"
echo "  - python-pillow (image handling)"
echo "  - chromaprint (already installed ✓)"
echo "  - ffmpeg (audio analysis)"
echo ""

read -p "Install these packages? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Installation cancelled"
    exit 0
fi

echo ""
echo -e "${GREEN}Installing packages...${NC}"
echo ""

# Install main packages
paru -S --needed beets python-pyacoustid python-pylast python-requests python-pillow ffmpeg

echo ""
echo -e "${GREEN}✓ Packages installed${NC}"
echo ""

# Verify installation
if command -v beet &> /dev/null; then
    echo -e "${GREEN}✓ Beets installed successfully${NC}"
    beet version
    echo ""
else
    echo -e "${RED}Error: Beets installation failed${NC}"
    exit 1
fi

# Check if config exists
if [[ -f ~/.config/beets/config.yaml ]]; then
    echo -e "${GREEN}✓ Beets config found${NC}"
    echo "  Location: ~/.config/beets/config.yaml"
else
    echo -e "${YELLOW}⚠ No config found${NC}"
    echo "  Config should already exist at ~/.config/beets/config.yaml"
fi

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════${NC}"
echo -e "${BLUE}  Next Steps${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════${NC}"
echo ""

echo "1. Stop Picard if it's running"
echo ""
echo "2. Import all music from TempMusic:"
echo "   cd ~/.config/dotfiles"
echo "   ./utils/music-import-with-beets.sh"
echo ""
echo "3. Or import single album:"
echo "   ./utils/music-import-album.sh \"Future Trance Vol.10\""
echo ""
echo "4. Check what was imported:"
echo "   beet ls"
echo "   beet stats"
echo ""

echo -e "${GREEN}Installation complete! 🎵${NC}"

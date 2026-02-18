#!/usr/bin/env bash
# Interactive duplicate file handler using Beets

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}═══════════════════════════════════════════════${NC}"
echo -e "${BLUE}  Duplicate Files Analysis${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════${NC}"
echo ""

# Check if beets is available
if ! command -v beet &> /dev/null; then
    echo -e "${RED}Error: Beets is not installed or not in PATH${NC}"
    echo "Install with: sudo apt install beets"
    exit 1
fi

# Check if library exists
if ! beet stats &>/dev/null; then
    echo -e "${YELLOW}Beets library not initialized yet${NC}"
    echo "Run first: beet import /mnt/linuxbro/media/2tb/Music"
    exit 1
fi

echo -e "${GREEN}Finding duplicates...${NC}"
echo ""

# Find duplicates by checksum (exact copies)
echo -e "${BLUE}1. Exact Duplicates (same file)${NC}"
echo "─────────────────────────────────────────────"
beet duplicates -k mb_trackid,albumartist,album,title

echo ""
echo -e "${BLUE}2. Similar Tracks (same song, different files)${NC}"
echo "─────────────────────────────────────────────"
beet duplicates

echo ""
echo "─────────────────────────────────────────────"
echo -e "${YELLOW}💡 Tips:${NC}"
echo ""
echo "To see full details of duplicates:"
echo "  beet duplicates -f '\$path - \$bitrate kbps - \$length'"
echo ""
echo "To move duplicates to review folder:"
echo "  beet duplicates -m /mnt/linuxbro/media/2tb/Beets/duplicates/"
echo ""
echo "To delete duplicates (keeps best quality):"
echo "  beet duplicates -d"
echo "  (Run with caution! Review first!)"
echo ""
echo "To see albums with duplicate tracks:"
echo "  beet duplicates -a"

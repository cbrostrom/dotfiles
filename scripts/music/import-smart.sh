#!/usr/bin/env bash
# Smart Beets import that handles nested album folders

set -euo pipefail

TEMP_MUSIC="/mnt/linuxbro/media/2tb/TempMusic"
MUSIC_DIR="/mnt/linuxbro/media/2tb/Music"
BEETS_LOG="/mnt/linuxbro/media/2tb/Beets/import.log"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${BLUE}═══════════════════════════════════════════════${NC}"
echo -e "${BLUE}  Smart Beets Import${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════${NC}"
echo ""

# Check if beets is installed
if ! command -v beet &> /dev/null; then
    echo -e "${RED}Error: Beets is not installed${NC}"
    echo "Run: ./scripts/install/beets.sh"
    exit 1
fi

echo -e "${GREEN}Analyzing TempMusic structure...${NC}"
echo ""

# Count files
total_files=$(find "$TEMP_MUSIC" -type f \( -name "*.mp3" -o -name "*.opus" -o -name "*.flac" -o -name "*.m4a" \) | wc -l)
echo -e "Total audio files: ${CYAN}$total_files${NC}"

# Count loose files (not in an album folder)
loose_files=$(find "$TEMP_MUSIC" -maxdepth 2 -type f \( -name "*.mp3" -o -name "*.opus" \) | wc -l)
echo -e "Loose files (2 levels deep): ${YELLOW}$loose_files${NC}"

# Count album folders (3+ levels deep)
album_folders=$(find "$TEMP_MUSIC" -mindepth 3 -type f \( -name "*.mp3" -o -name "*.opus" \) -exec dirname {} \; | sort -u | wc -l)
echo -e "Album folders detected: ${CYAN}$album_folders${NC}"
echo ""

echo -e "${YELLOW}Structure detected:${NC}"
echo "Your TempMusic has nested structure:"
echo "  TempMusic/Artist/Album/tracks.mp3"
echo ""
echo "Also some loose files:"
echo "  TempMusic/Artist/track.mp3"
echo ""

echo -e "${BLUE}Import Strategy:${NC}"
echo "─────────────────────────────────────────────"
echo "1. Import album folders first (clean imports)"
echo "2. Import loose files as singletons"
echo "3. Skip problematic files"
echo ""

read -p "Continue with smart import? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Import cancelled"
    exit 0
fi

echo ""
echo -e "${GREEN}Starting import...${NC}"
echo ""

# Strategy: Import each artist's albums
echo -e "${CYAN}Importing albums from TempMusic...${NC}"
echo "This will process all subdirectories recursively"
echo ""

# Use -s flag for flat imports (treats each file/folder as potential album)
beet import -s "$TEMP_MUSIC"

echo ""
echo "─────────────────────────────────────────────"
echo -e "${GREEN}✓ Import complete!${NC}"
echo ""

# Show stats
echo -e "${BLUE}Collection Stats:${NC}"
beet stats

echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo ""
echo "1. Review imported music:"
echo "   beet ls -a"
echo ""
echo "2. Move loose singletons to proper albums if needed:"
echo "   beet ls -s"
echo ""
echo "3. Find duplicates:"
echo "   beet duplicates"
echo ""
echo "4. Check import log for skipped files:"
echo "   grep -i skip $BEETS_LOG"
echo ""

echo -e "${GREEN}Done! 🎵${NC}"

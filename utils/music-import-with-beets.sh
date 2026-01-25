#!/usr/bin/env bash
# Import music from TempMusic to Music using Beets
# Beets will organize everything perfectly

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
echo -e "${BLUE}  Beets Music Import${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════${NC}"
echo ""

# Check if beets is installed
if ! command -v beet &> /dev/null; then
    echo -e "${RED}Error: Beets is not installed${NC}"
    echo ""
    echo "Install with:"
    echo "  paru -S beets python-pyacoustid"
    echo ""
    exit 1
fi

# Show what will happen
echo -e "${GREEN}📂 Source:${NC}      $TEMP_MUSIC"
echo -e "${GREEN}📂 Destination:${NC} $MUSIC_DIR"
echo -e "${GREEN}📝 Log file:${NC}    $BEETS_LOG"
echo ""

# Count files
file_count=$(find "$TEMP_MUSIC" -type f \( -name "*.mp3" -o -name "*.flac" -o -name "*.m4a" -o -name "*.ogg" -o -name "*.opus" \) | wc -l)
echo -e "${CYAN}Found $file_count audio files to import${NC}"
echo ""

# Show folder structure
echo -e "${YELLOW}Folders in TempMusic:${NC}"
ls -1 "$TEMP_MUSIC" | head -10
folder_count=$(ls -1 "$TEMP_MUSIC" | wc -l)
if [[ $folder_count -gt 10 ]]; then
    echo "... and $((folder_count - 10)) more"
fi
echo ""

# Ask for confirmation
echo -e "${YELLOW}═══════════════════════════════════════════════${NC}"
echo -e "${YELLOW}What Beets will do:${NC}"
echo ""
echo "✓ Scan all music files in TempMusic"
echo "✓ Match against MusicBrainz database"
echo "✓ Download album art"
echo "✓ Move files to Music/ with organized structure:"
echo "  Artist/Album/01 Track Title.mp3"
echo "✓ Update all metadata (tags)"
echo "✓ Skip duplicates automatically"
echo ""
echo -e "${YELLOW}═══════════════════════════════════════════════${NC}"
echo ""

read -p "Start import? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Import cancelled"
    exit 0
fi

echo ""
echo -e "${GREEN}Starting import...${NC}"
echo ""
echo -e "${CYAN}This might take a while (${file_count} files)${NC}"
echo -e "${CYAN}You can monitor progress in another terminal:${NC}"
echo -e "  tail -f $BEETS_LOG"
echo ""
echo "─────────────────────────────────────────────"
echo ""

# Start import
beet import "$TEMP_MUSIC"

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
echo "1. Check imported music:"
echo "   ls -lah $MUSIC_DIR"
echo ""
echo "2. Search your collection:"
echo "   beet ls artist:Pulsedriver"
echo "   beet ls year:2005"
echo ""
echo "3. Find duplicates:"
echo "   beet duplicates"
echo ""
echo "4. Fetch missing album art:"
echo "   beet fetchart"
echo ""
echo "5. Check import log for any issues:"
echo "   less $BEETS_LOG"
echo ""

# Check if any files were skipped
skipped=$(grep -c "skipping" "$BEETS_LOG" 2>/dev/null || echo "0")
if [[ $skipped -gt 0 ]]; then
    echo -e "${YELLOW}⚠ $skipped files were skipped${NC}"
    echo "  Check log for details: $BEETS_LOG"
    echo ""
fi

echo -e "${GREEN}Done! 🎵${NC}"

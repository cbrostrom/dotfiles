#!/usr/bin/env bash
# Import a single album or folder with Beets
# Usage: ./music-import-album.sh "path/to/album"

set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

if [[ $# -eq 0 ]]; then
    echo -e "${YELLOW}Usage:${NC} $0 <path-to-album-folder>"
    echo ""
    echo "Example:"
    echo "  $0 /mnt/linuxbro/media/2tb/TempMusic/Pulsedriver"
    echo ""
    echo "Or import specific album from TempMusic by name:"
    echo "  $0 \"Future Trance Vol.10\""
    exit 1
fi

TARGET="$1"

# If not absolute path, assume it's in TempMusic
if [[ ! "$TARGET" = /* ]]; then
    TARGET="/mnt/linuxbro/media/2tb/TempMusic/$TARGET"
fi

if [[ ! -d "$TARGET" ]]; then
    echo -e "${RED}Error: Directory not found: $TARGET${NC}"
    exit 1
fi

echo -e "${BLUE}═══════════════════════════════════════════════${NC}"
echo -e "${BLUE}  Import Single Album${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════${NC}"
echo ""
echo -e "${GREEN}Importing:${NC} $TARGET"
echo ""

# Count files
file_count=$(find "$TARGET" -type f \( -name "*.mp3" -o -name "*.flac" -o -name "*.m4a" \) | wc -l)
echo -e "${YELLOW}Found $file_count audio files${NC}"
echo ""

# List files
echo "Files:"
find "$TARGET" -type f \( -name "*.mp3" -o -name "*.flac" -o -name "*.m4a" \) -exec basename {} \; | sort | head -10
if [[ $file_count -gt 10 ]]; then
    echo "... and $((file_count - 10)) more"
fi
echo ""

read -p "Import this album? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cancelled"
    exit 0
fi

echo ""
echo -e "${GREEN}Importing...${NC}"
echo ""

beet import "$TARGET"

echo ""
echo -e "${GREEN}✓ Done!${NC}"

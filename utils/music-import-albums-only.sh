#!/usr/bin/env bash
# Import only album folders, skip loose files for now

set -euo pipefail

TEMP_MUSIC="/mnt/linuxbro/media/2tb/TempMusic"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${BLUE}═══════════════════════════════════════════════${NC}"
echo -e "${BLUE}  Import Albums Only (Skip Loose Files)${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════${NC}"
echo ""

# Find all album folders (3+ levels deep with audio files)
echo -e "${CYAN}Finding album folders...${NC}"
echo ""

album_dirs=()
while IFS= read -r dir; do
    album_dirs+=("$dir")
done < <(find "$TEMP_MUSIC" -mindepth 2 -maxdepth 3 -type d -exec sh -c 'ls -1 "$1"/*.mp3 2>/dev/null | head -1 > /dev/null && echo "$1"' _ {} \;)

echo -e "${GREEN}Found ${#album_dirs[@]} album folders${NC}"
echo ""

if [[ ${#album_dirs[@]} -eq 0 ]]; then
    echo -e "${YELLOW}No album folders found. Try importing directly:${NC}"
    echo "  beet import $TEMP_MUSIC"
    exit 0
fi

# Show sample
echo "Sample albums:"
for i in "${!album_dirs[@]}"; do
    if [[ $i -lt 10 ]]; then
        rel_path="${album_dirs[$i]#$TEMP_MUSIC/}"
        echo "  - $rel_path"
    fi
done

if [[ ${#album_dirs[@]} -gt 10 ]]; then
    echo "  ... and $((${#album_dirs[@]} - 10)) more"
fi

echo ""
read -p "Import these album folders? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cancelled"
    exit 0
fi

echo ""
echo -e "${GREEN}Importing albums...${NC}"
echo ""

# Import each album folder
count=0
for album_dir in "${album_dirs[@]}"; do
    ((count++))
    rel_path="${album_dir#$TEMP_MUSIC/}"
    echo -e "${CYAN}[$count/${#album_dirs[@]}]${NC} $rel_path"
    
    # Import this specific folder
    beet import "$album_dir" || true
    
    echo ""
done

echo ""
echo -e "${GREEN}✓ Album import complete!${NC}"
echo ""
echo "Stats:"
beet stats
echo ""
echo "To import remaining loose files:"
echo "  beet import -s $TEMP_MUSIC"

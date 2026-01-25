#!/usr/bin/env bash
# Clean up duplicate files in TempMusic - AUTO MODE (no prompts)

set -euo pipefail

TEMP_MUSIC="/mnt/linuxbro/media/2tb/TempMusic"
BACKUP_DIR="/mnt/linuxbro/media/2tb/TempMusic_duplicates_backup"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${BLUE}═══════════════════════════════════════════════${NC}"
echo -e "${BLUE}  TempMusic Duplicate Cleanup (AUTO)${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════${NC}"
echo ""

echo -e "${YELLOW}Finding duplicates...${NC}"
echo ""

# Count duplicates
duplicate_count=$(/usr/bin/find "$TEMP_MUSIC" \( -name "* (1).*" -o -name "* (2).*" -o -name "* (3).*" -o -name "* (4).*" \) 2>/dev/null | wc -l)

echo -e "${RED}Found $duplicate_count duplicate files${NC}"
echo ""

if [[ $duplicate_count -eq 0 ]]; then
    echo -e "${GREEN}No duplicates found!${NC}"
    exit 0
fi

echo -e "${GREEN}Creating backup directory...${NC}"
mkdir -p "$BACKUP_DIR"

echo -e "${GREEN}Moving duplicates to backup...${NC}"
echo ""

moved=0
# Find and move duplicates
while IFS= read -r file; do
    if [[ ! -f "$file" ]]; then
        continue
    fi
    
    # Get relative path
    rel_path="${file#$TEMP_MUSIC/}"
    target_dir="$BACKUP_DIR/$(dirname "$rel_path")"
    
    # Create target directory
    mkdir -p "$target_dir"
    
    # Move file
    mv "$file" "$target_dir/" 2>/dev/null && ((moved++)) || true
    
    if [[ $((moved % 100)) -eq 0 ]] && [[ $moved -gt 0 ]]; then
        echo -ne "\rMoved: $moved files..."
    fi
done < <(/usr/bin/find "$TEMP_MUSIC" \( -name "* (1).*" -o -name "* (2).*" -o -name "* (3).*" -o -name "* (4).*" \) 2>/dev/null)

echo -e "\r${GREEN}Moved: $moved files    ${NC}"
echo ""

# Clean up empty directories
echo -e "${CYAN}Cleaning up empty directories...${NC}"
/usr/bin/find "$TEMP_MUSIC" -type d -empty -delete 2>/dev/null || true

echo ""
echo -e "${GREEN}✓ Cleanup complete!${NC}"
echo ""

# Count remaining files
remaining=$(/usr/bin/find "$TEMP_MUSIC" \( -name "*.mp3" -o -name "*.opus" -o -name "*.flac" -o -name "*.m4a" \) 2>/dev/null | wc -l)
echo -e "Remaining files: ${CYAN}$remaining${NC}"
echo -e "Duplicates backed up to: ${YELLOW}$BACKUP_DIR${NC}"
echo ""

echo -e "${BLUE}Next steps:${NC}"
echo "1. Clear beets resume state:"
echo "   rm -f ~/.config/beets/state.pickle /mnt/linuxbro/media/2tb/Beets/state.pickle"
echo ""
echo "2. Import clean music:"
echo "   beet import -q $TEMP_MUSIC"
echo ""

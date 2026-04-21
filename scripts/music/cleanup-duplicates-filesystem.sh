#!/usr/bin/env bash
# Clean up duplicate files in TempMusic before import

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
echo -e "${BLUE}  TempMusic Duplicate Cleanup${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════${NC}"
echo ""

echo -e "${YELLOW}Analyzing duplicates...${NC}"
echo ""

# Find all duplicate patterns (files with " (1)", " (2)" etc)
duplicate_count=$(find "$TEMP_MUSIC" -type f \( -name "* (1).*" -o -name "* (2).*" -o -name "* (3).*" \) | wc -l)

echo -e "${RED}Found $duplicate_count duplicate files${NC}"
echo ""

if [[ $duplicate_count -eq 0 ]]; then
    echo -e "${GREEN}No duplicates found!${NC}"
    exit 0
fi

# Show sample
echo "Sample duplicates:"
find "$TEMP_MUSIC" -type f -name "* (1).*" | head -5
echo ""

echo -e "${YELLOW}Strategy:${NC}"
echo "1. Keep original files (without (1), (2) suffix)"
echo "2. Move duplicates to backup folder: $BACKUP_DIR"
echo "3. You can review and delete backup later"
echo ""

read -p "Proceed with cleanup? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cancelled"
    exit 0
fi

echo ""
echo -e "${GREEN}Creating backup directory...${NC}"
mkdir -p "$BACKUP_DIR"

echo -e "${GREEN}Moving duplicates...${NC}"
echo ""

moved=0
# Find and move duplicates while preserving structure
while IFS= read -r file; do
    # Get relative path
    rel_path="${file#$TEMP_MUSIC/}"
    target_dir="$BACKUP_DIR/$(dirname "$rel_path")"
    
    # Create target directory
    mkdir -p "$target_dir"
    
    # Move file
    mv "$file" "$target_dir/"
    ((moved++))
    
    if [[ $((moved % 100)) -eq 0 ]]; then
        echo -ne "\rMoved: $moved files..."
    fi
done < <(find "$TEMP_MUSIC" -type f \( -name "* (1).*" -o -name "* (2).*" -o -name "* (3).*" -o -name "* (4).*" \))

echo -e "\r${GREEN}Moved: $moved files    ${NC}"
echo ""

# Clean up empty directories
echo -e "${CYAN}Cleaning up empty directories...${NC}"
find "$TEMP_MUSIC" -type d -empty -delete 2>/dev/null || true

echo ""
echo -e "${GREEN}✓ Cleanup complete!${NC}"
echo ""

# Count remaining files
remaining=$(find "$TEMP_MUSIC" -type f \( -name "*.mp3" -o -name "*.opus" -o -name "*.flac" \) | wc -l)
echo -e "Remaining files: ${CYAN}$remaining${NC}"
echo -e "Duplicates backed up to: ${YELLOW}$BACKUP_DIR${NC}"
echo ""

echo -e "${BLUE}Next steps:${NC}"
echo "1. Import clean music:"
echo "   beet import -q $TEMP_MUSIC"
echo ""
echo "2. After successful import, check backup:"
echo "   ls -lah $BACKUP_DIR"
echo ""
echo "3. Delete backup if everything looks good:"
echo "   rm -rf $BACKUP_DIR"
echo ""

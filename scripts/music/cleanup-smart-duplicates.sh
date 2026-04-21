#!/usr/bin/env bash
# Smart duplicate removal - keeps highest quality version

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
echo -e "${BLUE}  Smart Duplicate Cleanup (Keep Best Quality)${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════${NC}"
echo ""

# Check if ffprobe is available
if ! command -v ffprobe &> /dev/null; then
    echo -e "${RED}Error: ffprobe not found (part of ffmpeg)${NC}"
    exit 1
fi

echo -e "${YELLOW}Finding duplicate groups...${NC}"
echo ""

mkdir -p "$BACKUP_DIR"

# Find all base filenames that have duplicates
declare -A file_groups

while IFS= read -r file; do
    # Get basename without (1), (2) etc
    basename=$(basename "$file")
    # Remove duplicate suffix: " (1)", " (2)", etc
    base="${basename% ([0-9])*}"
    
    # If no change, it's the original
    if [[ "$base" == "$basename" ]]; then
        base="$basename"
    fi
    
    dirname=$(dirname "$file")
    key="$dirname/$base"
    
    if [[ -z "${file_groups[$key]:-}" ]]; then
        file_groups["$key"]="$file"
    else
        file_groups["$key"]="${file_groups[$key]}|$file"
    fi
done < <(find "$TEMP_MUSIC" -type f \( -name "*.mp3" -o -name "*.opus" \))

# Process groups with duplicates
processed=0
groups_with_dupes=0

for key in "${!file_groups[@]}"; do
    files="${file_groups[$key]}"
    
    # Count files in group
    IFS='|' read -ra file_array <<< "$files"
    
    if [[ ${#file_array[@]} -le 1 ]]; then
        continue
    fi
    
    ((groups_with_dupes++))
done

if [[ $groups_with_dupes -eq 0 ]]; then
    echo -e "${GREEN}No duplicate groups found!${NC}"
    exit 0
fi

echo -e "${YELLOW}Found $groups_with_dupes duplicate groups${NC}"
echo ""
echo "Strategy: Keep highest bitrate, move others to backup"
echo ""

read -p "Proceed? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cancelled"
    exit 0
fi

echo ""
echo -e "${GREEN}Processing duplicates...${NC}"
echo ""

for key in "${!file_groups[@]}"; do
    files="${file_groups[$key]}"
    IFS='|' read -ra file_array <<< "$files"
    
    if [[ ${#file_array[@]} -le 1 ]]; then
        continue
    fi
    
    # Get bitrate for each file
    declare -A bitrates
    best_file=""
    best_bitrate=0
    
    for file in "${file_array[@]}"; do
        if [[ ! -f "$file" ]]; then
            continue
        fi
        
        bitrate=$(ffprobe -v error -show_entries format=bit_rate -of default=noprint_wrappers=1:nokey=1 "$file" 2>/dev/null || echo "0")
        bitrates["$file"]=$bitrate
        
        if [[ $bitrate -gt $best_bitrate ]]; then
            best_bitrate=$bitrate
            best_file="$file"
        fi
    done
    
    # Move non-best files to backup
    for file in "${file_array[@]}"; do
        if [[ "$file" != "$best_file" ]] && [[ -f "$file" ]]; then
            rel_path="${file#$TEMP_MUSIC/}"
            target_dir="$BACKUP_DIR/$(dirname "$rel_path")"
            mkdir -p "$target_dir"
            mv "$file" "$target_dir/"
            ((processed++))
        fi
    done
    
    if [[ $((processed % 10)) -eq 0 ]]; then
        echo -ne "\rProcessed: $processed files..."
    fi
done

echo -e "\r${GREEN}Processed: $processed files    ${NC}"
echo ""

# Clean up empty directories
find "$TEMP_MUSIC" -type d -empty -delete 2>/dev/null || true

remaining=$(find "$TEMP_MUSIC" -type f \( -name "*.mp3" -o -name "*.opus" \) | wc -l)

echo -e "${GREEN}✓ Done!${NC}"
echo ""
echo -e "Remaining files: ${CYAN}$remaining${NC}"
echo -e "Backed up: ${YELLOW}$processed${NC} files to $BACKUP_DIR"
echo ""
echo "Next: beet import -q $TEMP_MUSIC"

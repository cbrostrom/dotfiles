#!/usr/bin/env bash
# Music Collection Analysis Script
# Analyzes your music collection after Picard import

set -euo pipefail

MUSIC_DIR="/mnt/linuxbro/media/2tb/Music"
BEETS_DB="/mnt/linuxbro/media/2tb/Beets/library.db"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}═══════════════════════════════════════════════${NC}"
echo -e "${BLUE}  Music Collection Analysis${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════${NC}"
echo ""

# Check if music directory exists
if [[ ! -d "$MUSIC_DIR" ]]; then
    echo -e "${RED}Error: Music directory not found: $MUSIC_DIR${NC}"
    exit 1
fi

echo -e "${GREEN}📊 Collection Statistics${NC}"
echo "─────────────────────────────────────────────"

# Total files
total_files=$(find "$MUSIC_DIR" -type f \( -name "*.mp3" -o -name "*.flac" -o -name "*.m4a" -o -name "*.ogg" -o -name "*.opus" \) | wc -l)
echo -e "Total audio files: ${YELLOW}$total_files${NC}"

# File types breakdown
echo ""
echo -e "${GREEN}📁 File Types${NC}"
for ext in mp3 flac m4a ogg opus; do
    count=$(find "$MUSIC_DIR" -type f -name "*.$ext" 2>/dev/null | wc -l)
    if [[ $count -gt 0 ]]; then
        echo "  .$ext: $count"
    fi
done

# Total size
echo ""
echo -e "${GREEN}💾 Storage${NC}"
total_size=$(du -sh "$MUSIC_DIR" | cut -f1)
echo "  Total size: $total_size"

# Bitrate analysis for MP3s
echo ""
echo -e "${GREEN}🎵 MP3 Quality Analysis${NC}"
echo "─────────────────────────────────────────────"

low_quality=0
medium_quality=0
high_quality=0
vbr_files=0

while IFS= read -r file; do
    if [[ -f "$file" ]]; then
        bitrate=$(ffprobe -v error -show_entries format=bit_rate -of default=noprint_wrappers=1:nokey=1 "$file" 2>/dev/null || echo "0")
        
        if [[ "$bitrate" -gt 0 ]]; then
            if [[ $bitrate -lt 128000 ]]; then
                ((low_quality++))
            elif [[ $bitrate -lt 192000 ]]; then
                ((medium_quality++))
            else
                ((high_quality++))
            fi
        fi
    fi
done < <(find "$MUSIC_DIR" -type f -name "*.mp3" | head -100)  # Sample first 100 for speed

echo "  Sample analysis (first 100 MP3s):"
echo "    < 128 kbps (Low):     $low_quality"
echo "    128-192 kbps (Medium): $medium_quality"
echo "    > 192 kbps (High):     $high_quality"

if [[ $low_quality -gt 0 ]]; then
    echo ""
    echo -e "  ${RED}⚠ Found $low_quality low-quality files${NC}"
    echo "    Run: ./music-cleanup-find-low-quality.sh to see them"
fi

# Album art analysis
echo ""
echo -e "${GREEN}🎨 Album Art Status${NC}"
echo "─────────────────────────────────────────────"

# Count directories (albums)
total_albums=$(find "$MUSIC_DIR" -mindepth 2 -maxdepth 2 -type d | wc -l)
echo "  Total album folders: $total_albums"

# Count albums with cover art
albums_with_art=0
albums_without_art=0

while IFS= read -r album_dir; do
    if [[ -f "$album_dir/cover.jpg" ]] || [[ -f "$album_dir/folder.jpg" ]] || [[ -f "$album_dir/cover.png" ]] || [[ -f "$album_dir/folder.png" ]]; then
        ((albums_with_art++))
    else
        ((albums_without_art++))
    fi
done < <(find "$MUSIC_DIR" -mindepth 2 -maxdepth 2 -type d)

echo "  Albums with art:     $albums_with_art"
echo "  Albums without art:  $albums_without_art"

if [[ $albums_without_art -gt 0 ]]; then
    echo ""
    echo -e "  ${YELLOW}📌 $albums_without_art albums missing cover art${NC}"
    echo "    Run: beet fetchart"
fi

# Check for duplicates (basic filename check)
echo ""
echo -e "${GREEN}🔍 Potential Duplicates${NC}"
echo "─────────────────────────────────────────────"

duplicate_count=$(find "$MUSIC_DIR" -type f -name "*.mp3" -o -name "*.flac" | \
    xargs -I {} basename {} | \
    sort | uniq -d | wc -l)

if [[ $duplicate_count -gt 0 ]]; then
    echo -e "  ${RED}⚠ Found $duplicate_count potential duplicate filenames${NC}"
    echo "    Run: beet duplicates"
else
    echo -e "  ${GREEN}✓ No obvious duplicates found${NC}"
fi

# Beets database check
echo ""
echo -e "${GREEN}📚 Beets Database${NC}"
echo "─────────────────────────────────────────────"

if [[ -f "$BEETS_DB" ]]; then
    items_count=$(sqlite3 "$BEETS_DB" "SELECT COUNT(*) FROM items;" 2>/dev/null || echo "0")
    albums_count=$(sqlite3 "$BEETS_DB" "SELECT COUNT(*) FROM albums;" 2>/dev/null || echo "0")
    
    echo "  Items in database:  $items_count"
    echo "  Albums in database: $albums_count"
    
    if [[ $items_count -eq 0 ]]; then
        echo ""
        echo -e "  ${YELLOW}📌 Database is empty${NC}"
        echo "    Run: beet import /mnt/linuxbro/media/2tb/Music"
    fi
else
    echo -e "  ${YELLOW}Database not found (will be created on first import)${NC}"
fi

# Next steps
echo ""
echo -e "${BLUE}═══════════════════════════════════════════════${NC}"
echo -e "${BLUE}  Recommended Next Steps${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════${NC}"
echo ""

echo "1. Import into Beets (preserves Picard structure):"
echo "   beet import /mnt/linuxbro/media/2tb/Music"
echo ""
echo "2. Find and review duplicates:"
echo "   beet duplicates"
echo ""
echo "3. Fetch missing album art:"
echo "   beet fetchart"
echo ""
echo "4. Find low quality files:"
echo "   ./music-cleanup-find-low-quality.sh"
echo ""
echo "5. Check for corrupted files:"
echo "   beet bad"
echo ""

echo -e "${GREEN}✓ Analysis complete${NC}"

#!/usr/bin/env bash
# Find low-quality audio files in your music collection

set -euo pipefail

MUSIC_DIR="/mnt/linuxbro/media/2tb/Music"
MIN_BITRATE=192000  # 192 kbps

# Colors
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}═══════════════════════════════════════════════${NC}"
echo -e "${BLUE}  Low Quality Audio Files${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════${NC}"
echo ""
echo "Scanning for files under ${MIN_BITRATE} bps (192 kbps)..."
echo ""

low_quality_files=()
total_scanned=0

while IFS= read -r file; do
    ((total_scanned++))
    
    if [[ $((total_scanned % 50)) -eq 0 ]]; then
        echo -ne "\rScanned: $total_scanned files..."
    fi
    
    bitrate=$(ffprobe -v error -show_entries format=bit_rate -of default=noprint_wrappers=1:nokey=1 "$file" 2>/dev/null || echo "0")
    
    if [[ "$bitrate" -gt 0 ]] && [[ $bitrate -lt $MIN_BITRATE ]]; then
        bitrate_kb=$((bitrate / 1000))
        low_quality_files+=("$file|$bitrate_kb")
    fi
done < <(find "$MUSIC_DIR" -type f -name "*.mp3")

echo -e "\rScanned: $total_scanned files... Done!   "
echo ""

if [[ ${#low_quality_files[@]} -eq 0 ]]; then
    echo -e "${YELLOW}✓ No low-quality files found${NC}"
    exit 0
fi

echo -e "${RED}Found ${#low_quality_files[@]} low-quality files:${NC}"
echo "─────────────────────────────────────────────"
echo ""

for entry in "${low_quality_files[@]}"; do
    file="${entry%|*}"
    bitrate="${entry#*|}"
    
    # Get relative path for cleaner output
    rel_path="${file#$MUSIC_DIR/}"
    
    echo -e "${YELLOW}$bitrate kbps${NC} - $rel_path"
done

echo ""
echo "─────────────────────────────────────────────"
echo "Options:"
echo "1. Keep them (they might be rare/hard to find)"
echo "2. Mark for replacement (save list to file)"
echo "3. Delete them (not recommended)"
echo ""
echo "To save list to file:"
echo "  ./music-cleanup-find-low-quality.sh > low-quality-files.txt"

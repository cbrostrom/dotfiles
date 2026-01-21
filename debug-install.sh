#!/usr/bin/env bash

# Quick debug script

echo "=== Debug Install Script ==="
echo ""

EXTENSIONS_FILE="$HOME/.config/dotfiles/.config/cursor/extensions.json"

echo "1. Reading extensions list:"
EXTENSIONS=$(jq -r '.[].identifier' "$EXTENSIONS_FILE")
echo "First 5 extensions:"
echo "$EXTENSIONS" | head -5
echo "Total: $(echo "$EXTENSIONS" | wc -l)"
echo ""

echo "2. Getting installed extensions (directory scan):"
INSTALLED=$(ls -1 "$HOME/.cursor/extensions" | grep -v "^\." | sed 's/-[0-9].*//' | sort -u)
echo "First 5 installed:"
echo "$INSTALLED" | head -5
echo "Total: $(echo "$INSTALLED" | wc -l)"
echo ""

echo "3. Testing while loop:"
COUNT=0
while IFS= read -r ext; do
    [[ -z "$ext" ]] && continue
    echo "Processing: $ext"
    ((COUNT++))
    [[ $COUNT -ge 5 ]] && break
done <<< "$EXTENSIONS"

echo ""
echo "Loop processed: $COUNT extensions"

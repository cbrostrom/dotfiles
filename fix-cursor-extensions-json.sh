#!/usr/bin/env bash

# Fix Cursor's corrupted extensions.json on Linux

set -e

echo "=== Cursor Extensions.json Fix ==="
echo ""

CURSOR_EXTENSIONS_JSON="$HOME/.cursor/extensions/extensions.json"

# Backup the corrupted file
if [[ -f "$CURSOR_EXTENSIONS_JSON" ]]; then
    echo "1. Backing up corrupted extensions.json..."
    cp "$CURSOR_EXTENSIONS_JSON" "$CURSOR_EXTENSIONS_JSON.corrupted.backup"
    echo "✓ Backup created: $CURSOR_EXTENSIONS_JSON.corrupted.backup"
    echo ""
    
    echo "2. Checking file content..."
    echo "First 5 lines:"
    head -5 "$CURSOR_EXTENSIONS_JSON" || echo "Cannot read file"
    echo ""
    echo "File size: $(du -h "$CURSOR_EXTENSIONS_JSON" | cut -f1)"
    echo ""
fi

# Check what Cursor expects
echo "3. Cursor expects extensions.json to contain metadata for installed extensions."
echo "   Let's check if it's a valid JSON..."
if command -v jq &>/dev/null; then
    if jq empty "$CURSOR_EXTENSIONS_JSON" 2>/dev/null; then
        echo "✓ File is valid JSON"
        echo ""
        echo "Structure:"
        jq 'type' "$CURSOR_EXTENSIONS_JSON"
        jq 'if type == "array" then length else keys | length end' "$CURSOR_EXTENSIONS_JSON"
    else
        echo "✗ File is NOT valid JSON - this is the problem!"
        echo ""
        echo "Showing first 100 characters:"
        head -c 100 "$CURSOR_EXTENSIONS_JSON"
        echo ""
    fi
else
    echo "⚠ jq not installed, cannot validate JSON"
fi

echo ""
echo "4. Solution options:"
echo "   A) Delete the corrupted file - Cursor will regenerate it"
echo "   B) Regenerate it from installed extensions"
echo ""
read -p "Choose option (A/B): " choice

case $choice in
    [Aa])
        echo "Deleting corrupted file..."
        rm "$CURSOR_EXTENSIONS_JSON"
        echo "✓ Deleted. Restart Cursor to regenerate."
        ;;
    [Bb])
        echo "Regenerating from installed extensions..."
        
        # Get list of installed extension directories
        if [[ -d "$HOME/.cursor/extensions" ]]; then
            EXTENSIONS_DIR="$HOME/.cursor/extensions"
            
            echo "[]" > "$CURSOR_EXTENSIONS_JSON"
            echo "✓ Created empty extensions.json"
            echo "Restart Cursor to let it rebuild the metadata."
        else
            echo "✗ Extensions directory not found"
            exit 1
        fi
        ;;
    *)
        echo "Invalid choice"
        exit 1
        ;;
esac

echo ""
echo "=== Fix complete ==="
echo "Next step: Restart Cursor and try running cursor --list-extensions again"

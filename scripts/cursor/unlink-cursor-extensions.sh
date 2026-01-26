#!/usr/bin/env bash

# Unlink corrupted extensions.json symlink on Linux

set -e

echo "=== Removing extensions.json symlink ==="
echo ""

EXTENSIONS_JSON="$HOME/.cursor/extensions/extensions.json"

if [[ -L "$EXTENSIONS_JSON" ]]; then
    echo "Removing symlink: $EXTENSIONS_JSON"
    rm "$EXTENSIONS_JSON"
    echo "✓ Symlink removed"
    echo ""
    echo "Cursor will regenerate this file on next start"
    echo "Please restart Cursor now"
else
    echo "extensions.json is not a symlink (or doesn't exist)"
    ls -la "$EXTENSIONS_JSON" 2>/dev/null || echo "File not found"
fi

echo ""
echo "After Cursor restarts, test with:"
echo "  cursor --list-extensions 2>&1 | head"

#!/usr/bin/env bash

# Test Cursor CLI installation on Linux
# Run this on your Linux machine to debug extension installation

set -e

echo "=== Cursor CLI Debug Script ==="
echo ""

# Test 1: Find cursor command
echo "1. Testing 'cursor' command..."
if command -v cursor &>/dev/null; then
    echo "✓ cursor found: $(which cursor)"
    cursor --version 2>&1 | head -5
    echo ""
    echo "Testing --list-extensions..."
    cursor --list-extensions 2>&1 | head -5
    echo ""
    echo "Testing --install-extension..."
    cursor --install-extension aaron-bond.better-comments --force 2>&1
else
    echo "✗ cursor not found in PATH"
fi

echo ""
echo "2. Testing 'code' command..."
if command -v code &>/dev/null; then
    echo "✓ code found: $(which code)"
    code --version 2>&1 | head -5
    echo ""
    echo "Testing --list-extensions..."
    code --list-extensions 2>&1 | head -5
    echo ""
    echo "Testing --install-extension..."
    code --install-extension aaron-bond.better-comments --force 2>&1
else
    echo "✗ code not found in PATH"
fi

echo ""
echo "3. Checking common Cursor paths..."
PATHS=(
    "/usr/bin/cursor"
    "/usr/local/bin/cursor"
    "$HOME/.cursor-server/bin/cursor"
    "$HOME/.local/bin/cursor"
    "/opt/cursor/cursor"
    "/snap/cursor/current/usr/share/cursor/bin/cursor"
)

for path in "${PATHS[@]}"; do
    if [[ -f "$path" ]]; then
        echo "✓ Found: $path"
        "$path" --version 2>&1 | head -3
    fi
done

echo ""
echo "4. Checking Cursor installation directories..."
if [[ -d "$HOME/.cursor" ]]; then
    echo "✓ ~/.cursor exists"
    ls -la "$HOME/.cursor" 2>&1 | head -10
fi

if [[ -d "$HOME/.cursor/extensions" ]]; then
    echo "✓ Extensions directory exists"
    echo "Extensions count: $(ls -1 "$HOME/.cursor/extensions" | wc -l)"
fi

echo ""
echo "=== Debug complete ==="
echo "Copy the output and send it back for analysis"

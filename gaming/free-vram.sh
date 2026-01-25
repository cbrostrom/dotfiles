#!/usr/bin/env bash

# Free VRAM Script
# Closes unnecessary applications to free up VRAM for gaming

set -euo pipefail

echo "🎮 Freeing VRAM for Gaming..."
echo ""

# Check current VRAM usage
if command -v nvidia-smi &> /dev/null; then
    echo "📊 Current VRAM Usage:"
    nvidia-smi --query-gpu=memory.used,memory.total --format=csv,noheader,nounits | \
    awk '{printf "   Used: %d MB / %d MB (%.1f%%)\n", $1, $2, ($1/$2)*100}'
    echo ""
fi

echo "Closing unnecessary applications..."
echo ""

CLOSED=0

# Close browsers (except if you're using them for guides)
if pgrep -x zen-bin > /dev/null; then
    echo "  • Closing Zen Browser..."
    killall zen-bin 2>/dev/null || true
    ((CLOSED++))
fi

if pgrep -x firefox > /dev/null; then
    echo "  • Closing Firefox..."
    killall firefox 2>/dev/null || true
    ((CLOSED++))
fi

if pgrep -x chromium > /dev/null; then
    echo "  • Closing Chromium..."
    killall chromium 2>/dev/null || true
    ((CLOSED++))
fi

# Close communication apps
if pgrep -x evolution > /dev/null; then
    echo "  • Closing Evolution (Email)..."
    killall evolution 2>/dev/null || true
    ((CLOSED++))
fi

if pgrep -x thunderbird > /dev/null; then
    echo "  • Closing Thunderbird..."
    killall thunderbird 2>/dev/null || true
    ((CLOSED++))
fi

# Close Electron apps (Slack, Discord, etc.)
if pgrep electron36 > /dev/null; then
    echo "  • Closing Electron apps..."
    killall electron36 2>/dev/null || true
    ((CLOSED++))
fi

if pgrep electron37 > /dev/null; then
    killall electron37 2>/dev/null || true
    ((CLOSED++))
fi

# Close Apollo (if running)
if pgrep apollo > /dev/null; then
    echo "  • Closing Apollo..."
    killall apollo 2>/dev/null || true
    ((CLOSED++))
fi

# Close VS Code / Cursor (if not needed)
read -p "Close VS Code / Cursor? (y/N) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    if pgrep -x code > /dev/null; then
        echo "  • Closing VS Code..."
        killall code 2>/dev/null || true
        ((CLOSED++))
    fi
    if pgrep -x cursor > /dev/null; then
        echo "  • Closing Cursor..."
        killall cursor 2>/dev/null || true
        ((CLOSED++))
    fi
fi

# Wait for processes to close
sleep 2

echo ""
if [[ $CLOSED -gt 0 ]]; then
    echo "✅ Closed $CLOSED application(s)"
else
    echo "✅ No applications needed closing"
fi

# Show new VRAM usage
if command -v nvidia-smi &> /dev/null; then
    echo ""
    echo "📊 New VRAM Usage:"
    nvidia-smi --query-gpu=memory.used,memory.total --format=csv,noheader,nounits | \
    awk '{printf "   Used: %d MB / %d MB (%.1f%%)\n", $1, $2, ($1/$2)*100}'
    
    USED=$(nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits)
    AVAILABLE=$((8192 - USED))
    
    echo ""
    echo "💾 Available VRAM: ${AVAILABLE} MB"
    
    if [[ $AVAILABLE -lt 6000 ]]; then
        echo ""
        echo "⚠️  WARNING: Still less than 6GB available!"
        echo "   Avatar may crash due to low VRAM."
        echo ""
        echo "   Consider:"
        echo "   • Lowering in-game graphics to Medium"
        echo "   • Closing more applications"
        echo "   • Restarting GNOME Shell (Alt+F2, type 'r', Enter)"
    elif [[ $AVAILABLE -lt 7000 ]]; then
        echo ""
        echo "⚠️  VRAM is tight. Lower graphics settings in-game to Medium/High."
    else
        echo ""
        echo "✅ Good! You should have enough VRAM for Avatar."
        echo "   Still recommend Medium/High graphics settings."
    fi
fi

echo ""
echo "🎮 Ready to game!"

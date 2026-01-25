#!/usr/bin/env bash

# Ubisoft Connect Cleanup
# Kills lingering Ubisoft Connect processes after game closes

set -euo pipefail

echo "🧹 Cleaning up Ubisoft Connect processes..."

KILLED=0

# Find and kill Ubisoft Connect processes
for proc in UplayWebCore.exe upc.exe UbisoftConnect.exe uplay.exe; do
    if pgrep -f "$proc" > /dev/null 2>&1; then
        echo "  • Killing $proc..."
        pkill -f "$proc" 2>/dev/null || true
        ((KILLED++))
    fi
done

# Also kill any Wine processes that might be hanging
if pgrep -f "ubisoft" > /dev/null 2>&1; then
    echo "  • Killing remaining Ubisoft processes..."
    pkill -f "ubisoft" 2>/dev/null || true
    ((KILLED++))
fi

if [[ $KILLED -gt 0 ]]; then
    echo "✅ Cleaned up $KILLED process(es)"
else
    echo "✅ No Ubisoft processes found"
fi

# Check if any are still running
sleep 1
if pgrep -f "Uplay\|upc\|UbisoftConnect" > /dev/null 2>&1; then
    echo "⚠️  Some processes still running. Forcing kill..."
    pkill -9 -f "Uplay\|upc\|UbisoftConnect" 2>/dev/null || true
    echo "✅ Force killed remaining processes"
fi

echo "🎮 Ready for next game!"

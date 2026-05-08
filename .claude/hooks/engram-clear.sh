#!/usr/bin/env bash
# Clear the Engram autosave queue. Run after saving the queued items.
set -euo pipefail
queue="${XDG_STATE_HOME:-$HOME/.local/state}/claude-code/engram-pending.txt"
if [[ -f "$queue" ]]; then
    : > "$queue"
    echo "engram queue cleared: $queue"
else
    echo "no queue at $queue"
fi

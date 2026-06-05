#!/usr/bin/env bash
# Clear the Engram autosave queue for the current scope (work or personal).
set -euo pipefail

state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/claude-code"

if [[ "$PWD" == "$HOME/Projects/Shopify"* ]] || \
   [[ "$PWD" == "$HOME/Projects/Clients"* ]] || \
   [[ "$PWD" == "$HOME/Projects/Internal"* ]] || \
   [[ "$PWD" == "$HOME/Work"* ]]; then
    queue="$state_dir/engram-pending-work.txt"
else
    queue="$state_dir/engram-pending-personal.txt"
fi

if [[ -f "$queue" ]]; then
    : > "$queue"
    echo "engram queue cleared: $queue"
else
    echo "no queue at $queue"
fi

#!/usr/bin/env bash
# UserPromptSubmit hook: inject queued commits for the current scope only.
# Work sessions see work queue; personal sessions see personal queue.
# Output goes to stdout — harness wraps it as additional context for the model.
set -uo pipefail

state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/claude-code"

# Detect scope from $PWD.
if [[ "$PWD" == "$HOME/Projects/Shopify"* ]] || \
   [[ "$PWD" == "$HOME/Projects/Clients"* ]] || \
   [[ "$PWD" == "$HOME/Projects/Internal"* ]] || \
   [[ "$PWD" == "$HOME/Work"* ]]; then
    queue="$state_dir/engram-pending-work.txt"
    engram_tool="engram-work"
else
    queue="$state_dir/engram-pending-personal.txt"
    engram_tool="engram"
fi

[[ -f "$queue" ]] || exit 0
[[ -s "$queue" ]] || exit 0

cat <<EOF
=== ENGRAM AUTOSAVE QUEUE ===
The Stop hook detected commits in previous turn(s) that are not yet saved
to Engram. Save them via mem_save BEFORE addressing the user's new message
if the changes are significant (refactors, new features, fixes worth recalling).

Use a stable topic_key so future saves UPDATE the same observation instead of
creating duplicates. Examples:
    topic_key: "architecture/dotfiles-modules"
    topic_key: "bugfix/vscodium-wsl-git"
    topic_key: "feature/dotfiles-tui"

After saving, clear the queue:
    bash ~/.claude/hooks/engram-clear.sh

Pending entries:

$(cat "$queue")
=== END ENGRAM AUTOSAVE QUEUE ===
EOF

exit 0

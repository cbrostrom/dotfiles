#!/usr/bin/env bash
# UserPromptSubmit hook: if there are queued commits from previous turns,
# inject a system-reminder so Claude saves them to Engram before responding.
#
# Output goes to stdout — the harness wraps it as additional context for the model.
# Errors / debug go to stderr (suppressed).
set -uo pipefail

queue="${XDG_STATE_HOME:-$HOME/.local/state}/claude-code/engram-pending.txt"

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

#!/usr/bin/env bash
# tuna-notify.sh — Claude Code hook. Focus Claude.app + bounce dock when
# Notification event fires (Claude needs user input or long task done).
#
# Wire as Notification hook in ~/.claude/settings.json:
#   "Notification": [{ "hooks": [{ "type": "command",
#       "command": "/Users/Christian.Brostrom/.claude/hooks/tuna-notify.sh",
#       "async": true }] }]
#
# Hook receives JSON on stdin. We don't parse it — just attention-grab.

set -u

# 1. Ping via tuna URL scheme: opens Claude.app (existing binding d→a).
#    Falls back to `open -a` if tuna URL handler not registered.
if ! /usr/bin/open "tuna://run/path.%252FApplications%252FClaude.app/Open" 2>/dev/null; then
  /usr/bin/open -a "Claude" 2>/dev/null || true
fi

# 2. Bounce dock + system sound via osascript.
/usr/bin/osascript <<'AS' 2>/dev/null || true
tell application "System Events"
  set frontmost of (first process whose name is "Claude") to true
end tell
AS

/usr/bin/afplay /System/Library/Sounds/Glass.aiff >/dev/null 2>&1 &

# Always succeed — hook failure must not block Claude.
exit 0

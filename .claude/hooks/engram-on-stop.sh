#!/usr/bin/env bash
# Stop-event hook: detect git commits made during the last turn and queue them
# so the next UserPromptSubmit can remind Claude to save them to Engram.
#
# Strategy:
#   1. For the current working dir (if it's a git repo), record HEAD.
#   2. Compare to last-recorded HEAD for that repo.
#   3. If HEAD moved, append new commit list to the pending queue.
#
# State files (under XDG_STATE_HOME):
#   claude-code/engram-pending.txt        human-readable queue, read by UserPromptSubmit
#   claude-code/last-head-<repo-hash>     last HEAD per repo (one file per repo seen)
set -uo pipefail

state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/claude-code"
mkdir -p "$state_dir" 2>/dev/null || exit 0

queue="$state_dir/engram-pending.txt"

# Find the git toplevel for $PWD; bail if not in a repo.
repo=""
if git -C "$PWD" rev-parse --show-toplevel >/dev/null 2>&1; then
    repo="$(git -C "$PWD" rev-parse --show-toplevel)"
fi
[[ -z "$repo" ]] && exit 0

# Per-repo state file (sha1 of toplevel path).
repo_hash="$(printf '%s' "$repo" | sha1sum | cut -c1-12)"
last_head_file="$state_dir/last-head-$repo_hash"

curr_head="$(git -C "$repo" rev-parse HEAD 2>/dev/null || echo "")"
[[ -z "$curr_head" ]] && exit 0

prev_head=""
[[ -f "$last_head_file" ]] && prev_head="$(cat "$last_head_file" 2>/dev/null || echo "")"

# Always update the recorded head.
echo "$curr_head" > "$last_head_file"

# First time we see this repo — nothing to compare against, just baseline.
[[ -z "$prev_head" ]] && exit 0
# No new commits — nothing to do.
[[ "$prev_head" == "$curr_head" ]] && exit 0

# Get new commits between prev and curr.
new_commits="$(git -C "$repo" log --oneline "$prev_head..$curr_head" 2>/dev/null)"
[[ -z "$new_commits" ]] && exit 0

# Append to queue.
{
    echo "── $(date '+%Y-%m-%d %H:%M:%S') · $repo ──"
    echo "$new_commits"
    echo
} >> "$queue"

exit 0

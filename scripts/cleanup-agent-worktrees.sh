#!/usr/bin/env bash
set -euo pipefail

# Remove orphaned agent worktrees created by Workflow tool (isolation: worktree).
# Should auto-delete but don't when agents exit abnormally or are locked.

find ~/Projects ~/Work -path "*/.claude/worktrees/agent-*" -maxdepth 6 -type d -prune 2>/dev/null | while read -r wt; do
  repo=$(git -C "$wt" rev-parse --show-toplevel 2>/dev/null) || continue
  git -C "$repo" worktree unlock "$wt" 2>/dev/null || true
  git -C "$repo" worktree remove --force "$wt" 2>/dev/null || rm -rf "$wt"
  echo "removed: $wt"
done

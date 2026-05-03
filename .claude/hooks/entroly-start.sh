#!/bin/bash
# Ensures entroly proxy is running at session start.
# Starts it in the background if not already up.

if ! command -v entroly &>/dev/null; then
  exit 0
fi

if ss -tlnp 2>/dev/null | grep -q ":9377"; then
  exit 0
fi

nohup entroly proxy >/tmp/entroly.log 2>&1 &
disown

# Give it a moment to bind
sleep 1

# Silently re-sync Claude config (symlinks + settings merge, no git pull)
DOTFILES_DIR="${DOTFILES_DIR:-$HOME/.config/dotfiles}"
[[ ! -d "$DOTFILES_DIR" ]] && DOTFILES_DIR="$HOME/dotfiles"
if [[ -f "$DOTFILES_DIR/scripts/claude/install-claude-config.sh" ]]; then
    bash "$DOTFILES_DIR/scripts/claude/install-claude-config.sh" >/dev/null 2>&1 &
    disown
fi

exit 0

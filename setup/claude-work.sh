#!/usr/bin/env bash
# Work-only Claude Code setup (macOS work machine only). Stow owns the files under
# stow/claude-work; this script owns the effects: skill links, plugin, rtk hook, settings merge.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$ROOT/setup/lib.sh"
activate_fnm

command -v claude >/dev/null 2>&1 || { skip "claude not installed"; exit 0; }
command -v jq >/dev/null 2>&1 || die "jq is required for the Claude Code guard hooks"
CLAUDE_HOME="$HOME/.claude"
mkdir -p "$CLAUDE_HOME/skills" "$CLAUDE_HOME/context-mode"

# Shared skills (no higgins/dockhand/dotfiles). Links point at the shared skill store.
SKILLS=(writing commit shopify atlassian-agent systematic-debugging verification-before-completion code-cleaner paseo paseo-handoff call codebase scout)
for s in "${SKILLS[@]}"; do
    src="$HOME/.agents/skills/$s"
    dst="$CLAUDE_HOME/skills/$s"
    [[ -e "$src" ]] || { warn "work skill missing: $s"; continue; }
    [[ -L "$dst" || ! -e "$dst" ]] && ln -sfn "$src" "$dst" && ok "skill $s" || warn "skip $s: $dst exists and is not a link"
done

# context-mode plugin: same engine as Pi, hook-enforced routing. Data dir is set in settings (CONTEXT_MODE_DATA_DIR).
if ! claude plugin list 2>/dev/null | grep -q "context-mode"; then
    claude plugin marketplace add mksglu/context-mode >/dev/null 2>&1 || warn "marketplace add failed"
    claude plugin install context-mode@context-mode >/dev/null 2>&1 || warn "context-mode plugin install failed"
fi

# rtk: Bash rewrite hook for Claude Code, hook only (no CLAUDE.md edits).
if command -v rtk >/dev/null 2>&1; then
    rtk init -g --hook-only --auto-patch >/dev/null 2>&1 || warn "rtk init failed"
fi

# mw (mcporter pinned to the work servers) must be on PATH for Claude Bash calls.
mkdir -p "$HOME/.local/bin"
ln -sfn "$CLAUDE_HOME/bin/mw" "$HOME/.local/bin/mw" && ok "mw on PATH"

# aislop post-edit check (parity with pi)
if command -v aislop >/dev/null 2>&1; then
    aislop hook install claude >/dev/null 2>&1 || warn "aislop hook install claude failed"
fi

# Settings apply last. Flags: --pull | --force | --check (see merge_settings.py).
python3 "$ROOT/setup/claude-work/merge_settings.py" \
    "$ROOT/sources/claude-work/settings.json" \
    "$CLAUDE_HOME/settings.json" "$@"
ok "claude-work settings merged"

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
mkdir -p "$CLAUDE_HOME/skills"

# Shared skills (no higgins/dockhand/dotfiles). Links point at the shared skill store.
SKILLS=(writing commit shopify atlassian-agent systematic-debugging verification-before-completion code-cleaner paseo paseo-handoff call codebase aislop)
for s in "${SKILLS[@]}"; do
    src="$HOME/.agents/skills/$s"
    dst="$CLAUDE_HOME/skills/$s"
    [[ -e "$src" ]] || { warn "work skill missing: $s"; continue; }
    [[ -L "$dst" || ! -e "$dst" ]] && ln -sfn "$src" "$dst" && ok "skill $s" || warn "skip $s: $dst exists and is not a link"
done

# plannotator plugin: plan review on ExitPlanMode. The plugin does not ship the CLI binary;
# install it with the minimal installer from the plannotator docs (not run here).
if command -v claude >/dev/null 2>&1 && ! claude plugin list 2>/dev/null | grep -q "plannotator@plannotator"; then
    claude plugin marketplace add backnotprop/plannotator >/dev/null 2>&1 || warn "plannotator marketplace add failed"
    claude plugin install plannotator@plannotator >/dev/null 2>&1 || warn "plannotator plugin install failed"
fi
command -v plannotator >/dev/null 2>&1 || warn "plannotator CLI missing: run the minimal installer from the plannotator docs"

# rtk: no `rtk init`; ~/.agents/hooks/bash-guard runs `rtk hook claude` after its checks.
command -v rtk >/dev/null 2>&1 || warn "rtk missing: Bash commands run without rtk rewrites"
# macOS reads the RTK config from Application Support; point it at the stowed copy.
if [[ "$(uname -s)" == Darwin ]]; then
    rtk_dir="$HOME/Library/Application Support/rtk"
    mkdir -p "$rtk_dir"
    ln -sfn "$HOME/.config/rtk/config.toml" "$rtk_dir/config.toml" && ok "rtk config linked"
fi

# mw (mcporter pinned to the work servers) must be on PATH for Claude Bash calls.
mkdir -p "$HOME/.local/bin"
ln -sfn "$CLAUDE_HOME/bin/mw" "$HOME/.local/bin/mw" && ok "mw on PATH"

# aislop is run by hand (aislop scan --changes); no post-edit hook.

# Settings apply last. Flags: --pull | --force | --check (see merge_settings.py).
python3 "$ROOT/setup/claude-work/merge_settings.py" \
    "$ROOT/sources/claude-work/settings.json" \
    "$CLAUDE_HOME/settings.json" "$@"
ok "claude-work settings merged"

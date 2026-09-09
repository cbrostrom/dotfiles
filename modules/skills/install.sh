#!/usr/bin/env bash
set -euo pipefail
. "$DOTFILES_DIR/modules/_lib/log.sh"

# Shared skills live in ~/dotfiles/.agents/skills and are exposed via:
#   ~/.agents/skills  (canonical discovery path for Pi / Cursor / others)
#   ~/.cursor/skills  → ~/.agents/skills
#
# Dotfiles itself is the source of truth — this module only wires discovery links.

cursor_skills_dir="$HOME/.cursor/skills"
agents_skills_dir="$HOME/.agents/skills"
src_skills_dir="$DOTFILES_DIR/.agents/skills"

mkdir -p "$HOME/.cursor" "$HOME/.agents"

if [[ -d "$src_skills_dir" ]]; then
    if [[ ! -e "$agents_skills_dir" || -L "$agents_skills_dir" ]]; then
        ln -sfn "$src_skills_dir" "$agents_skills_dir"
        ok "linked agents skills: $agents_skills_dir -> $src_skills_dir"
    else
        warn "$agents_skills_dir exists and is not a symlink — leaving it untouched"
    fi
else
    warn "no .agents/skills in dotfiles — skipping"
    exit 0
fi

if [[ ! -e "$cursor_skills_dir" || -L "$cursor_skills_dir" ]]; then
    ln -sfn "$agents_skills_dir" "$cursor_skills_dir"
    ok "linked Cursor skills: $cursor_skills_dir -> $agents_skills_dir"
else
    warn "$cursor_skills_dir exists and is not a symlink — leaving it untouched"
fi

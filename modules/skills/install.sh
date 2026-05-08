#!/usr/bin/env bash
set -euo pipefail
. "$DOTFILES_DIR/modules/_lib/log.sh"

list="$DOTFILES_DIR/.claude/skills/skills.list"
skills_dir="$HOME/.claude/skills"

if [[ ! -f "$list" ]]; then
    warn "skills.list not found at $list — nothing to do"
    exit 0
fi

mkdir -p "$skills_dir"
log "installing Claude Code skills from $list …"

while IFS= read -r source || [[ -n "$source" ]]; do
    [[ "$source" =~ ^#|^[[:space:]]*$ ]] && continue
    skill_name="$(basename "$source" | sed 's/-skill$//')"
    if [[ -d "$HOME/.agents/skills/$skill_name" ]]; then
        ok "skill already installed: $skill_name"
    else
        log "installing skill: $source"
        npx --yes skills add "$source" --agent "Claude Code" --scope global --non-interactive 2>/dev/null \
            || warn "skill install failed: $source"
    fi
    target="$HOME/.agents/skills/$skill_name"
    link="$skills_dir/$skill_name"
    if [[ -d "$target" && (! -L "$link" || "$(readlink -f "$link" 2>/dev/null)" != "$target") ]]; then
        ln -sf "$target" "$link"
        ok "linked: $link -> $target"
    fi
done < "$list"

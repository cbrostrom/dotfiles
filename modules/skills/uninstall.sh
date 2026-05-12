#!/usr/bin/env bash
set -euo pipefail
. "$DOTFILES_DIR/modules/_lib/log.sh"
. "$DOTFILES_DIR/modules/_lib/lists.sh"
. "$DOTFILES_DIR/modules/_lib/unlink.sh"

base="$DOTFILES_DIR/.claude/skills/skills.list"
skills_dir="$HOME/.claude/skills"

log "removing Claude Code skill symlinks from $skills_dir…"

if [[ -f "$base" ]]; then
    while IFS= read -r source || [[ -n "$source" ]]; do
        skill_name="$(basename "$source" | sed 's/-skill$//')"
        link="$skills_dir/$skill_name"
        if [[ -L "$link" ]]; then
            if [[ "${UNLINK_DRY_RUN:-0}" == "1" ]]; then
                echo "  would remove: $link"
            else
                rm -- "$link" && ok "  removed: $link"
            fi
        fi
    done < <(lists_merge "$base")
fi

ok "skills reset complete (npm-installed skill payloads in ~/.agents/skills left intact)"

#!/usr/bin/env bash
set -euo pipefail
. "$DOTFILES_DIR/modules/_lib/log.sh"
. "$DOTFILES_DIR/modules/_lib/lists.sh"

base="$DOTFILES_DIR/.claude/skills/skills.list"
skills_dir="$HOME/.claude/skills"
# Manifest of successfully installed sources — avoids re-running npx on repeated
# installs. Keyed by source string, so renamed dirs don't cause false misses.
manifest="${XDG_STATE_HOME:-$HOME/.local/state}/claude-skills.installed"

if [[ ! -f "$base" ]]; then
    warn "skills.list not found at $base — nothing to do"
    exit 0
fi

mkdir -p "$skills_dir" "$(dirname "$manifest")"
[[ -f "$manifest" ]] || touch "$manifest"

overlays="$(lists_active_paths "$base" | xargs -n1 basename 2>/dev/null | tr '\n' ' ')"
log "installing Claude Code skills (layers: ${overlays})…"

while IFS= read -r source || [[ -n "$source" ]]; do
    if grep -qxF "$source" "$manifest" 2>/dev/null; then
        ok "skill already installed: $source"
    else
        log "installing skill: $source"
        if npx --yes skills add "$source" --agent "Claude Code" --scope global --non-interactive 2>/dev/null; then
            echo "$source" >> "$manifest"
        else
            warn "skill install failed: $source"
        fi
    fi
    # Re-link in case ~/.agents/skills/ was cleared or link is stale.
    skill_name="$(basename "$source" | sed 's/-skill$//')"
    target="$HOME/.agents/skills/$skill_name"
    link="$skills_dir/$skill_name"
    if [[ -d "$target" && (! -L "$link" || "$(readlink -f "$link" 2>/dev/null)" != "$target") ]]; then
        ln -sf "$target" "$link"
        ok "linked: $link -> $target"
    fi
done < <(lists_merge "$base")

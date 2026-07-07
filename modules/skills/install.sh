#!/usr/bin/env bash
set -euo pipefail
. "$DOTFILES_DIR/modules/_lib/log.sh"
. "$DOTFILES_DIR/modules/_lib/lists.sh"

base="$DOTFILES_DIR/.claude/skills/skills.list"
skills_dir="$HOME/.claude/skills"
cursor_skills_dir="$HOME/.cursor/skills"
agents_skills_dir="$HOME/.agents/skills"
# Manifest for externally installed npx skills (not local .agents/skills/).
manifest="${XDG_STATE_HOME:-$HOME/.local/state}/claude-skills.installed"

mkdir -p "$skills_dir" "$(dirname "$manifest")" "$HOME/.cursor" "$agents_skills_dir"
[[ -f "$manifest" ]] || touch "$manifest"

# ~/.cursor/skills → ~/.agents/skills (always, regardless of npx skills list)
if [[ ! -e "$cursor_skills_dir" || -L "$cursor_skills_dir" ]]; then
    ln -sfn "$agents_skills_dir" "$cursor_skills_dir"
    ok "linked Cursor skills: $cursor_skills_dir -> $agents_skills_dir"
else
    warn "$cursor_skills_dir exists and is not a symlink — leaving it untouched"
fi

if [[ ! -f "$base" ]]; then
    ok "no skills.list — symlink done (all skills live in .agents/skills/)"
    exit 0
fi

overlays="$(lists_active_paths "$base" | xargs -n1 basename 2>/dev/null | tr '\n' ' ')"
log "installing shared Agent Skills (layers: ${overlays})…"

while IFS= read -r source || [[ -n "$source" ]]; do
    skill_name="$(basename "$source" | sed 's/-skill$//')"
    agents_dir="$agents_skills_dir/$skill_name"

    if grep -qxF "$source" "$manifest" 2>/dev/null; then
        ok "skill already installed: $source"
    elif [[ -d "$agents_dir" ]]; then
        # Already present on disk (e.g. installed on another machine via dotfiles sync)
        echo "$source" >> "$manifest"
        ok "skill found on disk, recorded: $source"
    else
        log "installing skill: $source"
        if timeout 60 npx --yes skills add "$source" --agent "Claude Code" --scope global --non-interactive 2>/dev/null; then
            echo "$source" >> "$manifest"
        else
            warn "skill install failed or timed out: $source"
        fi
    fi
    # Re-link in case ~/.agents/skills/ was cleared or link is stale.
    target="$agents_dir"
    link="$skills_dir/$skill_name"
    if [[ -d "$target" && (! -L "$link" || "$(readlink -f "$link" 2>/dev/null)" != "$target") ]]; then
        ln -sf "$target" "$link"
        ok "linked: $link -> $target"
    fi
done < <(lists_merge "$base")

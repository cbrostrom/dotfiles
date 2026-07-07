#!/usr/bin/env bash
# map-doctor.sh — AI setup audit (read-only)
#
# Usage:
#   map-doctor.sh              Print report to stdout
#   map-doctor.sh --save       Also write to $VAULT_AI/_ops/ai-audit-<date>.md

set -euo pipefail

if (( BASH_VERSINFO[0] < 4 )); then
    for _b in /opt/homebrew/bin/bash /usr/local/bin/bash; do
        [[ -x "$_b" ]] && exec "$_b" "$0" "$@"
    done
    echo "${0##*/}: bash 4+ required" >&2; exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
CONFIG_FILE="$DOTFILES_DIR/config/projects-map.conf"

source "$SCRIPT_DIR/lib.sh"
[[ -f "$CONFIG_FILE" ]] && source "$CONFIG_FILE"

SAVE=0
for arg in "$@"; do
    case "$arg" in
        --save) SAVE=1 ;;
        -h|--help) sed -n '2,6p' "$0"; exit 0 ;;
    esac
done

VAULT_AI="${VAULT_AI:-$HOME/Vaults/AI}"
CLAUDE_SKILLS="$HOME/.claude/skills"
AGENTS_SKILLS="$HOME/.agents/skills"
CURSOR_SKILLS="$HOME/.cursor/skills"
DOTFILES_AGENTS="$DOTFILES_DIR/.agents/skills"

declare -a FIX REVIEW INFO

_fix()    { FIX+=("$*"); }
_review() { REVIEW+=("$*"); }
_info()   { INFO+=("$*"); }

# ── 1. Skill layer duplicates ──────────────────────────────────────────────────
# Canonical: ~/.agents/skills/  Source: dotfiles/.agents/skills/
# .claude/skills/ should only have: symlinks → ~/.agents/ OR dotfiles-local skills
if [[ -d "$CLAUDE_SKILLS" ]]; then
    while IFS= read -r entry; do
        name=$(basename "$entry")
        [[ "$name" == ".gitignore" || "$name" == "skills.list" ]] && continue
        if [[ -d "$entry" && ! -L "$entry" ]]; then
            # Real dir in .claude/skills/ — check if same skill exists in .agents/
            if [[ -d "$AGENTS_SKILLS/$name" ]]; then
                _fix "Skill duplicate: ~/.claude/skills/$name/ is a real dir but ~/.agents/skills/$name/ exists — promote or remove the claude copy"
            else
                _review "Skill in ~/.claude/skills/$name/ has no counterpart in ~/.agents/skills/ — consider promoting to shared layer"
            fi
        fi
    done < <(find "$CLAUDE_SKILLS" -maxdepth 1 -mindepth 1 2>/dev/null)
fi

# ── 2. Orphan symlinks ────────────────────────────────────────────────────────
for skills_dir in "$CLAUDE_SKILLS" "$CURSOR_SKILLS"; do
    [[ -d "$skills_dir" ]] || continue
    while IFS= read -r link; do
        target=$(readlink "$link" 2>/dev/null || echo "")
        if [[ -L "$link" && ! -e "$link" ]]; then
            _fix "Orphan symlink: $link → $target (target missing)"
        fi
    done < <(find "$skills_dir" -maxdepth 1 -type l 2>/dev/null)
done

# ── 3. Cursor cache size ──────────────────────────────────────────────────────
cursor_size_kb=$(du -sk "$HOME/.cursor" 2>/dev/null | awk '{print $1}')
cursor_size_mb=$(( cursor_size_kb / 1024 ))
if [[ $cursor_size_mb -gt 1500 ]]; then
    # Find the real large subdirs, not assumed paths
    large=$(du -sh "$HOME/.cursor"/*/  2>/dev/null \
        | sort -rh | awk -F'\t' '$1~/[0-9]M|[0-9]G/ {printf "%s (%s)  ", $2, $1}' \
        | sed "s|$HOME/||g")
    _fix "~/.cursor is ${cursor_size_mb}MB — large subdirs: ${large}. Safe: rm -rf ~/.cursor/acp-sessions ~/.cursor/ai-tracking. extensions/ = installed extensions (keep). projects/ = per-project state (prune old manually)."
elif [[ $cursor_size_mb -gt 500 ]]; then
    _review "~/.cursor is ${cursor_size_mb}MB — run: du -sh ~/.cursor/*/ | sort -rh | head -8"
else
    _info "~/.cursor size: ${cursor_size_mb}MB (OK)"
fi

# cursor-agent cache
if [[ -d "$HOME/.local/share/cursor-agent" ]]; then
    ca_size_kb=$(du -sk "$HOME/.local/share/cursor-agent" 2>/dev/null | awk '{print $1}')
    ca_size_mb=$(( ca_size_kb / 1024 ))
    if [[ $ca_size_mb -gt 200 ]]; then
        _review "~/.local/share/cursor-agent is ${ca_size_mb}MB — review contents before clearing"
    else
        _info "~/.local/share/cursor-agent size: ${ca_size_mb}MB (OK)"
    fi
fi

# ── 4. Stale/disabled modules ─────────────────────────────────────────────────
modules_conf="$DOTFILES_DIR/modules.conf"
if [[ -f "$modules_conf" ]]; then
    while IFS= read -r line; do
        [[ "$line" =~ ^!(.+) ]] || continue
        mod="${BASH_REMATCH[1]}"
        mod_dir="$DOTFILES_DIR/modules/$mod"
        if [[ -d "$mod_dir" ]]; then
            _review "Disabled module '!$mod' still has directory: modules/$mod/ — archive or delete if truly abandoned"
        fi
    done < "$modules_conf"
fi

# ── 5. lean-ctx remnants ──────────────────────────────────────────────────────
# Exclude: policy/doc lines, cleanup legacy tuples, plugin cache, this script itself
_lean_ctx_hits() {
    grep -r "lean-ctx\|lean_ctx" "$DOTFILES_DIR" \
        --include="*.md" --include="*.sh" --include="*.json" \
        --include="*.yaml" --include="*.yml" --include="*.mdc" \
        -l 2>/dev/null \
        | grep -v "map-doctor\|\.codex/\.tmp" \
        | while IFS= read -r f; do
            # Skip if all matches are policy/doc notes or legacy-cleanup tuples
            if grep -q "lean-ctx\|lean_ctx" "$f" 2>/dev/null \
               && ! grep "lean-ctx\|lean_ctx" "$f" 2>/dev/null \
                    | grep -qE "No lean-ctx|lean-ctx — removed|legacy lean-ctx|lean-ctx-rewrite"; then
                echo "$f"
            fi
        done
}
_lc_files=$(_lean_ctx_hits | sed "s|$DOTFILES_DIR/||" | tr '\n' ' ')
[[ -n "$_lc_files" ]] && _fix "lean-ctx remnants (active references): ${_lc_files}-- remove"

# ── 6. Repomix / graphify cache files ────────────────────────────────────────
repomix_count=$(find "$HOME" -maxdepth 4 \( -name 'repomix-output*' -o -name 'repomix-out*' \) 2>/dev/null | wc -l | tr -d ' ')
graphify_count=$(find "$HOME" -maxdepth 4 \( -name 'graphify-out*' -o -name '.graphify_version' \) 2>/dev/null | wc -l | tr -d ' ')
[[ $repomix_count -gt 0 ]] && _review "$repomix_count repomix output file(s) found under ~ — delete or add to .gitignore"
[[ $graphify_count -gt 0 ]] && _review "$graphify_count graphify artifact(s) found under ~ — delete or add to .gitignore"

# ── 7. Disabled skill dirs (.disabled-*) ─────────────────────────────────────
for skills_dir in "$CLAUDE_SKILLS" "$AGENTS_SKILLS"; do
    [[ -d "$skills_dir" ]] || continue
    while IFS= read -r d; do
        _fix "Disabled skill dir: $d — delete (git history preserves it)"
    done < <(find "$skills_dir" -maxdepth 1 -type d -name '.disabled-*' 2>/dev/null)
done

# ── 8. MCP server sprawl check ────────────────────────────────────────────────
claude_json="$HOME/.claude.json"
if [[ -f "$claude_json" ]]; then
    mcp_count=$(python3 -c "
import json, sys
try:
    d = json.load(open('$claude_json'))
    mcps = d.get('mcpServers', {})
    print(len(mcps))
except: print(0)
" 2>/dev/null || echo 0)
    if [[ "$mcp_count" -gt 15 ]]; then
        _review "$mcp_count MCP servers in ~/.claude.json — verify all are managed by dotfiles modules (run: project-mcp list)"
    else
        _info "$mcp_count MCP servers in ~/.claude.json"
    fi
fi

# ── 9. Zellij remnants ───────────────────────────────────────────────────────
if [[ -d "$HOME/.zellij-projects" ]]; then
    zp_count=$(ls "$HOME/.zellij-projects" 2>/dev/null | wc -l | tr -d ' ')
    _review "~/.zellij-projects/ has $zp_count entries — modules.conf has !zellij; consider removing this dir"
fi

# ── Report ────────────────────────────────────────────────────────────────────
_print_report() {
    printf '# AI setup doctor — %s\n' "$(date '+%Y-%m-%d %H:%M')"
    printf '_Host: %s · dotfiles: %s_\n\n' "$(hostname -s)" "$DOTFILES_DIR"

    printf '## [fix] — action required (%d)\n\n' "${#FIX[@]}"
    if [[ ${#FIX[@]} -gt 0 ]]; then
        for item in "${FIX[@]}"; do printf -- '- %s\n' "$item"; done
    else
        printf '_None_\n'
    fi

    printf '\n## [review] — investigate (%d)\n\n' "${#REVIEW[@]}"
    if [[ ${#REVIEW[@]} -gt 0 ]]; then
        for item in "${REVIEW[@]}"; do printf -- '- %s\n' "$item"; done
    else
        printf '_None_\n'
    fi

    printf '\n## [info] — informational (%d)\n\n' "${#INFO[@]}"
    for item in "${INFO[@]}"; do printf -- '- %s\n' "$item"; done
}

_print_report

if [[ $SAVE -eq 1 ]]; then
    ops_dir="$VAULT_AI/_ops"
    mkdir -p "$ops_dir"
    out="$ops_dir/ai-audit-$(date +%F).md"
    _print_report > "$out"
    printf '\nSaved: %s\n' "$out" >&2
fi

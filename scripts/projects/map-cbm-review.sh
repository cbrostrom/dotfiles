#!/usr/bin/env bash
# map-cbm-review.sh — classify codebase-memory projects vs allowlist (R0-02)
# Default: write review JSON only. Deletions require --apply --yes.

set -euo pipefail

if ((BASH_VERSINFO[0] < 4)); then
    for _b in /opt/homebrew/bin/bash /usr/local/bin/bash; do
        [[ -x "$_b" ]] && exec "$_b" "$0" "$@"
    done
    echo "${0##*/}: bash 4+ required" >&2
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
CONFIG_FILE="$DOTFILES_DIR/config/projects-map.conf"

source "$SCRIPT_DIR/lib.sh"
[[ -f "$CONFIG_FILE" ]] && source "$CONFIG_FILE"

require_cmd jq mcporter

APPLY=0
YES=0
for arg in "$@"; do
    case "$arg" in
        --apply) APPLY=1 ;;
        --yes) YES=1 ;;
        -h | --help)
            sed -n '2,4p' "$0"
            echo "  --apply --yes   Delete projects marked recommended_deletion (explicit approval)"
            exit 0
            ;;
    esac
done

ALLOWLIST="${ALLOWLIST_JSON:-$HOME/.cache/repo-orientation/allowlist.json}"
OUT="${CBM_REVIEW_JSON:-$HOME/.cache/repo-orientation/cbm-deletion-review.json}"
mkdir -p "$(dirname "$OUT")"

declare -A ALLOW_PATHS=()
if [[ -f "$ALLOWLIST" ]]; then
    while IFS= read -r path; do
        [[ -n "$path" ]] && ALLOW_PATHS["$path"]=1
    done < <(jq -r '.repos[] | select(.persist=="allow") | .path' "$ALLOWLIST")
else
    warn "No allowlist at $ALLOWLIST — run: kb map scan"
fi

raw=$(mcporter call codebase-memory-mcp list_projects)

classify_one() {
    local name="$1" path="$2" nodes="$3"
    local rec=false class reason
    if path_denied_for_persist "$path"; then
        class=invalid-path; reason=deny_substring; rec=true
    elif [[ "$path" == *"/private/var/"* ]] || [[ "$path" == *"opencode-"* ]]; then
        class=ephemeral-temp; reason=temp_dir; rec=true
    elif [[ "$(repo_git_kind "$path")" == "worktree" ]]; then
        class=ephemeral-worktree; reason=git_worktree; rec=true
    elif [[ "$nodes" -le 1 ]]; then
        class=invalid-minimal; reason=single_node; rec=true
    elif [[ -n "${ALLOW_PATHS[$path]:-}" ]]; then
        class=active-allowed; reason=in_allowlist; rec=false
    elif [[ -d "$path/.git" ]] || [[ -f "$path/.git" ]]; then
        class=orphan-git; reason=not_in_allowlist; rec=true
    else
        class=invalid-directory; reason=not_git; rec=true
    fi
    jq -nc \
        --arg name "$name" \
        --arg path "$path" \
        --argjson nodes "$nodes" \
        --arg classification "$class" \
        --arg reason "$reason" \
        --argjson recommended_deletion "$rec" \
        '{name:$name,path:$path,nodes:$nodes,classification:$classification,reason:$reason,recommended_deletion:$recommended_deletion}'
}

tmp=$(mktemp)
: >"$tmp"
while IFS= read -r line; do
    printf '%s\n' "$line" >>"$tmp"
done < <(jq -c '.projects[]' <<<"$raw" | while read -r proj; do
    name=$(jq -r '.name' <<<"$proj")
    path=$(jq -r '.root_path' <<<"$proj")
    nodes=$(jq -r '.nodes' <<<"$proj")
    classify_one "$name" "$path" "$nodes"
done)

jq -s --arg gen "$(date -u +%Y-%m-%dT%H:%M:%SZ)" '{
    plan_id: "repo-orientation-mvp",
    task_id: "R0-02",
    generated_at: $gen,
    allowlist: $allowlist,
    projects: .,
    recommended_deletion_count: ([.[] | select(.recommended_deletion)] | length)
}' --arg allowlist "$ALLOWLIST" "$tmp" >"$OUT"
rm -f "$tmp"

rec_count=$(jq '.recommended_deletion_count' "$OUT")
ok "Review written: $OUT ($rec_count marked for deletion review)"

if [[ $APPLY -eq 1 ]]; then
    if [[ ${CBM_DELETE_REQUIRES_APPLY:-1} -ne 1 ]]; then
        err "CBM_DELETE_REQUIRES_APPLY disabled in config"
        exit 1
    fi
    if [[ $YES -ne 1 ]]; then
        err "Refusing to delete without --yes (review file: $OUT)"
        exit 1
    fi
    while IFS= read -r name; do
        [[ -z "$name" ]] && continue
        log "Deleting index: $name"
        mcporter call codebase-memory-mcp delete_project "project=$name" || warn "delete failed: $name"
    done < <(jq -r '.projects[] | select(.recommended_deletion) | .name' "$OUT")
    ok "Apply complete"
fi

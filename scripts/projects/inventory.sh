#!/usr/bin/env bash
# Scan ~/Projects, output _inventory.{md,json} + plan.template.yml
#
# Usage:
#   inventory.sh                  # scan and write reports
#   inventory.sh --no-clean-size  # skip slow source-only size calculation

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

require_cmd fd jq git du awk

CLEAN_SIZE=1
for arg in "$@"; do
    case "$arg" in
        --no-clean-size) CLEAN_SIZE=0 ;;
        -h|--help)
            sed -n '2,7p' "$0"; exit 0 ;;
    esac
done

OUT_JSON="$PROJECTS_ROOT/_inventory.json"
OUT_MD="$PROJECTS_ROOT/_inventory.md"
OUT_PLAN="$PROJECTS_ROOT/plan.template.yml"

log "Scanning $PROJECTS_ROOT for git repos (this can take a moment)…"

mapfile -t REPO_DIRS < <(
    cd "$PROJECTS_ROOT" && fd -t d -H -d 6 '^\.git$' \
        -E node_modules -E vendor 2>/dev/null \
        | sed 's|/\.git/*$||' | sort -u
)

ok "Found ${#REPO_DIRS[@]} git repos"

# ---------- Collect data ----------
JSON_ENTRIES=()
declare -a STALE DIRTY NESTED LOOSE_FILES EMPTY_DIRS DUP_NAMES SECURITY
declare -A NAME_COUNT REMOTE_COUNT
declare -A REPO_DATA  # rel → tab-separated record

count=0
for rel in "${REPO_DIRS[@]}"; do
    abs="$PROJECTS_ROOT/$rel"
    [[ -d "$abs" ]] || continue
    count=$((count+1))
    printf '\r[*] processing %d/%d: %-60s' "$count" "${#REPO_DIRS[@]}" "${rel:0:60}" >&2

    size_total=$(repo_size "$abs")
    if [[ $CLEAN_SIZE -eq 1 ]]; then
        size_clean=$(repo_size_clean "$abs")
    else
        size_clean=0
    fi
    last=$(git_last_commit_iso "$abs")
    age=$(iso_age_days "$last")
    branch=$(git_branch "$abs")
    dirty=$(git_dirty_count "$abs")
    remote=$(git_remote_url "$abs")
    stack=$(detect_stack "$abs")
    name=$(basename "$rel")

    # collision tracking
    NAME_COUNT[$name]=$(( ${NAME_COUNT[$name]:-0} + 1 ))
    [[ -n "$remote" ]] && REMOTE_COUNT[$remote]=$(( ${REMOTE_COUNT[$remote]:-0} + 1 ))

    flags=()
    [[ -n "$age" && "$age" -gt 365 ]] && flags+=("STALE") && STALE+=("$rel ($age days)")
    [[ "$dirty" -gt 0 ]] && flags+=("DIRTY") && DIRTY+=("$rel ($dirty changes)")

    parent_abs="$(dirname "$abs")"
    if [[ "$parent_abs" != "$PROJECTS_ROOT" ]] && [[ -d "$parent_abs/.git" ]]; then
        flags+=("NESTED_GIT")
        NESTED+=("$rel inside $(realpath --relative-to="$PROJECTS_ROOT" "$parent_abs" 2>/dev/null || echo "$parent_abs")")
    fi

    flags_str=$(IFS=,; echo "${flags[*]:-}")

    REPO_DATA[$rel]="$size_total\t$size_clean\t$last\t$age\t$branch\t$dirty\t$remote\t$stack\t$name\t$flags_str"

    JSON_ENTRIES+=("$(jq -n \
        --arg path "$rel" \
        --arg name "$name" \
        --argjson size_total "${size_total:-0}" \
        --argjson size_clean "${size_clean:-0}" \
        --arg last_commit "$last" \
        --arg age_days "${age:-}" \
        --arg branch "$branch" \
        --argjson dirty "${dirty:-0}" \
        --arg remote "$remote" \
        --arg stack "$stack" \
        --arg flags "$flags_str" \
        '{path:$path,name:$name,size_total:$size_total,size_clean:$size_clean,last_commit:$last_commit,age_days:$age_days,branch:$branch,dirty:$dirty,remote:$remote,stack:$stack,flags:($flags|split(",")|map(select(length>0)))}'
    )")
done
printf '\r%80s\r' '' >&2
ok "Collected metadata for $count repos"

# ---------- Detect duplicates ----------
for name in "${!NAME_COUNT[@]}"; do
    [[ "${NAME_COUNT[$name]}" -gt 1 ]] && DUP_NAMES+=("$name (${NAME_COUNT[$name]}x)")
done

for url in "${!REMOTE_COUNT[@]}"; do
    [[ "${REMOTE_COUNT[$url]}" -gt 1 ]] && DUP_NAMES+=("[remote] $url (${REMOTE_COUNT[$url]}x)")
done

# ---------- Loose files in category roots ----------
for cat in Clients Docker Internal Private Shopify Workspaces; do
    [[ -d "$PROJECTS_ROOT/$cat" ]] || continue
    while IFS= read -r f; do
        LOOSE_FILES+=("$cat/$(basename "$f")")
    done < <(find "$PROJECTS_ROOT/$cat" -maxdepth 1 -type f ! -name '.DS_Store' 2>/dev/null)
done

# also root-level files in ~/Projects
while IFS= read -r f; do
    LOOSE_FILES+=("$(basename "$f")")
done < <(find "$PROJECTS_ROOT" -maxdepth 1 -type f ! -name '.DS_Store' ! -name '_inventory.*' ! -name 'plan*.yml' 2>/dev/null)

# ---------- Empty dirs ----------
while IFS= read -r d; do
    [[ -z "$d" ]] && continue
    EMPTY_DIRS+=("${d#"$PROJECTS_ROOT/"}")
done < <(find "$PROJECTS_ROOT" -mindepth 2 -maxdepth 3 -type d -empty 2>/dev/null)

# ---------- Security scan ----------
while IFS= read -r f; do
    SECURITY+=("$(realpath --relative-to="$PROJECTS_ROOT" "$f" 2>/dev/null || echo "$f")")
done < <(find "$PROJECTS_ROOT" -maxdepth 4 -type f \( \
    -name 'id_rsa' -o -name 'id_ed25519' -o -name '*_rsa' -o -name '*_ed25519' \
    -o -name '.env.local' -o -name '.env.production' \) 2>/dev/null)

# ---------- Write JSON ----------
log "Writing $OUT_JSON"
{
    printf '{"generated":"%s","root":"%s","repos":[' "$(date -u +%FT%TZ)" "$PROJECTS_ROOT"
    first=1
    for entry in "${JSON_ENTRIES[@]}"; do
        [[ $first -eq 1 ]] && first=0 || printf ','
        printf '%s' "$entry"
    done
    printf '],"problems":{'
    printf '"duplicates":%s,' "$(printf '%s\n' "${DUP_NAMES[@]:-}" | jq -R . | jq -s 'map(select(length>0))')"
    printf '"loose_files":%s,' "$(printf '%s\n' "${LOOSE_FILES[@]:-}" | jq -R . | jq -s 'map(select(length>0))')"
    printf '"empty_dirs":%s,' "$(printf '%s\n' "${EMPTY_DIRS[@]:-}" | jq -R . | jq -s 'map(select(length>0))')"
    printf '"security":%s,' "$(printf '%s\n' "${SECURITY[@]:-}" | jq -R . | jq -s 'map(select(length>0))')"
    printf '"stale":%s,' "$(printf '%s\n' "${STALE[@]:-}" | jq -R . | jq -s 'map(select(length>0))')"
    printf '"dirty":%s,' "$(printf '%s\n' "${DIRTY[@]:-}" | jq -R . | jq -s 'map(select(length>0))')"
    printf '"nested_git":%s' "$(printf '%s\n' "${NESTED[@]:-}" | jq -R . | jq -s 'map(select(length>0))')"
    printf '}}\n'
} | jq . > "$OUT_JSON"

ok "Wrote $OUT_JSON"

# ---------- Write Markdown ----------
log "Writing $OUT_MD"
{
    printf '# Projects Inventory\n\n'
    printf '_Generated %s_\n\n' "$(date)"
    printf '**Total repos:** %d\n\n' "${#REPO_DIRS[@]}"

    printf '## Issues\n\n'
    printf '### Security (review immediately)\n'
    if [[ ${#SECURITY[@]} -gt 0 ]]; then
        for s in "${SECURITY[@]}"; do printf -- '- `%s`\n' "$s"; done
    else
        printf '_None_\n'
    fi

    printf '\n### Duplicates (name or remote)\n'
    if [[ ${#DUP_NAMES[@]} -gt 0 ]]; then
        for d in "${DUP_NAMES[@]}"; do printf -- '- %s\n' "$d"; done
    else
        printf '_None_\n'
    fi

    printf '\n### Nested git repos\n'
    if [[ ${#NESTED[@]} -gt 0 ]]; then
        for n in "${NESTED[@]}"; do printf -- '- `%s`\n' "$n"; done
    else
        printf '_None_\n'
    fi

    printf '\n### Stale (>365 days, %d repos)\n' "${#STALE[@]}"
    for s in "${STALE[@]:-}"; do [[ -n "$s" ]] && printf -- '- `%s`\n' "$s"; done

    printf '\n### Dirty (uncommitted changes, %d repos)\n' "${#DIRTY[@]}"
    for d in "${DIRTY[@]:-}"; do [[ -n "$d" ]] && printf -- '- `%s`\n' "$d"; done

    printf '\n### Loose files in category roots\n'
    for f in "${LOOSE_FILES[@]:-}"; do [[ -n "$f" ]] && printf -- '- `%s`\n' "$f"; done

    printf '\n### Empty dirs\n'
    for e in "${EMPTY_DIRS[@]:-}"; do [[ -n "$e" ]] && printf -- '- `%s`\n' "$e"; done

    printf '\n## All repos\n\n'
    printf '| Path | Stack | Branch | Last commit | Age (d) | Size | Source size | Dirty | Flags |\n'
    printf '|---|---|---|---|---:|---:|---:|---:|---|\n'
    for rel in "${REPO_DIRS[@]}"; do
        IFS=$'\t' read -r size_total size_clean last age branch dirty remote stack name flags <<< "${REPO_DATA[$rel]}"
        printf '| `%s` | %s | %s | %s | %s | %s | %s | %s | %s |\n' \
            "$rel" "$stack" "$branch" "${last:0:10}" "${age:-?}" \
            "$(human_size "${size_total:-0}")" "$(human_size "${size_clean:-0}")" \
            "$dirty" "$flags"
    done
} > "$OUT_MD"

ok "Wrote $OUT_MD"

# ---------- Generate plan.template.yml ----------
log "Writing $OUT_PLAN (suggested moves)"
"$SCRIPT_DIR/plan-gen.sh" "$OUT_JSON" > "$OUT_PLAN"
ok "Wrote $OUT_PLAN"

ok "Done. Review:"
printf '  %s\n' "$OUT_MD"
printf '  %s\n' "$OUT_PLAN"

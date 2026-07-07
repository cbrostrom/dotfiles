#!/usr/bin/env bash
# map-scan.sh — build personal/projects-registry.md from _inventory.json
#
# Usage:
#   map-scan.sh                   Reuse _inventory.json if <24h old
#   map-scan.sh --refresh-inventory  Force re-run of inventory.sh first

set -euo pipefail

# Re-exec with bash 4+ if the shebang resolved to /bin/bash (3.2 on macOS).
if (( BASH_VERSINFO[0] < 4 )); then
    for _b in /opt/homebrew/bin/bash /usr/local/bin/bash; do
        [[ -x "$_b" ]] && exec "$_b" "$0" "$@"
    done
    echo "${0##*/}: bash 4+ required (found $BASH_VERSION)" >&2; exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
CONFIG_FILE="$DOTFILES_DIR/config/projects-map.conf"

# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

[[ -f "$CONFIG_FILE" ]] || { err "Missing config: $CONFIG_FILE"; exit 1; }
# shellcheck source=../../config/projects-map.conf
source "$CONFIG_FILE"

require_cmd jq git

REFRESH=0
for arg in "$@"; do
    case "$arg" in
        --refresh-inventory) REFRESH=1 ;;
        -h|--help) sed -n '2,7p' "$0"; exit 0 ;;
    esac
done

OUT_JSON="$PROJECTS_ROOT/_inventory.json"

# ── Ensure inventory is fresh ──────────────────────────────────────────────────
_run_inventory() {
    # inventory.sh calls plan-gen.sh at the end; plan-gen.sh may fail independently.
    # The JSON is written before plan-gen runs, so tolerate non-zero exit and
    # verify the JSON exists ourselves.
    "$BASH" "$SCRIPT_DIR/inventory.sh" --no-clean-size || {
        [[ -f "$OUT_JSON" ]] || { err "inventory.sh failed and $OUT_JSON was not written"; exit 1; }
        warn "inventory.sh exited non-zero (plan.template.yml may be missing — non-fatal)"
    }
}

if [[ $REFRESH -eq 1 || ! -f "$OUT_JSON" ]]; then
    log "Running inventory.sh…"
    _run_inventory
else
    age_sec=$(( $(date +%s) - $(date -r "$OUT_JSON" +%s 2>/dev/null || echo 0) ))
    if [[ $age_sec -gt 86400 ]]; then
        log "Inventory stale ($(( age_sec / 3600 ))h) — refreshing…"
        _run_inventory
    else
        log "Reusing inventory ($(( age_sec / 3600 ))h old)"
    fi
fi

[[ -f "$OUT_JSON" ]] || { err "No inventory at $OUT_JSON"; exit 1; }

log "Building registry…"

declare -a ROWS
total=0; with_brain=0; with_codebase=0; issue_count=0

# ── Projects root repos (from inventory JSON) ──────────────────────────────────
while IFS=$'\t' read -r rel name stack flags; do
    abs="$PROJECTS_ROOT/$rel"
    category=$(infer_category "$rel")
    brain_yn="no";     has_brain    "$name" && { brain_yn="yes";    with_brain=$((with_brain+1)); }
    codebase_yn="no";  has_codebase "$abs"  && { codebase_yn="yes"; with_codebase=$((with_codebase+1)); }
    [[ -n "$flags" ]] && issue_count=$((issue_count+1))
    ROWS+=("$(registry_row "$name" "$abs" "$category" "$stack" "$brain_yn" "$codebase_yn" "$flags")")
    total=$((total+1))
done < <(jq -r '.repos[] | [.path, .name, .stack, (.flags | join(","))] | @tsv' "$OUT_JSON")

# ── Extra repos (outside PROJECTS_ROOT) ───────────────────────────────────────
if [[ -v EXTRA_REPOS ]]; then
    for abs in "${EXTRA_REPOS[@]}"; do
        [[ -d "$abs/.git" ]] || continue
        slug=$(basename "$abs")
        stack=$(detect_stack "$abs")
        brain_yn="no";     has_brain    "$slug" && { brain_yn="yes";    with_brain=$((with_brain+1)); }
        codebase_yn="no";  has_codebase "$abs"  && { codebase_yn="yes"; with_codebase=$((with_codebase+1)); }
        ROWS+=("$(registry_row "$slug" "$abs" "personal" "$stack" "$brain_yn" "$codebase_yn" "")")
        total=$((total+1))
    done
fi

# ── Extract problems from inventory JSON ───────────────────────────────────────
dup_count=$(jq '.problems.duplicates | length' "$OUT_JSON")
stale_count=$(jq '.problems.stale | length' "$OUT_JSON")
security_count=$(jq '.problems.security | length' "$OUT_JSON")

# ── Write registry ─────────────────────────────────────────────────────────────
mkdir -p "$(dirname "$REGISTRY_PATH")"
{
    printf '# Projects registry — %s\n' "$(hostname -s)"
    printf '_Updated: %s · %d repos · scan: kb map scan_\n\n' \
        "$(date '+%Y-%m-%d %H:%M')" "$total"
    printf '| slug | path | type | stack | brain | codebase | flags |\n'
    printf '|------|------|------|-------|-------|----------|-------|\n'
    for row in "${ROWS[@]}"; do
        printf '%s\n' "$row"
    done
    printf '\n## Issues (from last scan)\n'
    [[ $dup_count -gt 0 ]] && \
        printf -- '- **Duplicates:** %d name/remote collisions — see _inventory.md\n' "$dup_count"
    [[ $stale_count -gt 0 ]] && \
        printf -- '- **Stale (>365d):** %d repos\n' "$stale_count"
    [[ $security_count -gt 0 ]] && \
        printf -- '- **Security:** %d .env/key files in tree — rotate/review\n' "$security_count"
    [[ $dup_count -eq 0 && $stale_count -eq 0 && $security_count -eq 0 ]] && \
        printf -- '_No issues detected._\n'
} > "$REGISTRY_PATH"

ok "Registry written: $REGISTRY_PATH"
printf '\nSummary: %d repos · %d with brain · %d with CODEBASE · %d with issues\n' \
    "$total" "$with_brain" "$with_codebase" "$issue_count"

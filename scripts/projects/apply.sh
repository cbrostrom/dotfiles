#!/usr/bin/env bash
# Execute approved moves from plan.yml.
#
# Usage:
#   apply.sh                           # dry-run (default)
#   apply.sh --execute                 # perform moves
#   apply.sh --rollback <journal-file> # undo previous run
#   apply.sh --plan path/to/plan.yml   # custom plan file (default: $PROJECTS_ROOT/plan.yml)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

require_cmd awk

MODE="dry-run"
PLAN="$PROJECTS_ROOT/plan.yml"
ROLLBACK_FILE=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --execute) MODE="execute"; shift ;;
        --dry-run) MODE="dry-run"; shift ;;
        --rollback) MODE="rollback"; ROLLBACK_FILE="${2:?--rollback needs path}"; shift 2 ;;
        --plan) PLAN="${2:?--plan needs path}"; shift 2 ;;
        -h|--help) sed -n '2,8p' "$0"; exit 0 ;;
        *) err "Unknown arg: $1"; exit 1 ;;
    esac
done

JOURNAL_DIR="$PROJECTS_ROOT/_journal"
mkdir -p "$JOURNAL_DIR"

# ---------- Rollback ----------
if [[ "$MODE" == "rollback" ]]; then
    [[ -f "$ROLLBACK_FILE" ]] || { err "Journal not found: $ROLLBACK_FILE"; exit 1; }
    log "Rolling back operations in $ROLLBACK_FILE"
    # Read in reverse, undo each MOVE
    tac "$ROLLBACK_FILE" 2>/dev/null || tail -r "$ROLLBACK_FILE" | while IFS=$'\t' read -r ts op from to; do
        case "$op" in
            MOVE)
                if [[ -e "$to" && ! -e "$from" ]]; then
                    log "undo: $to → $from"
                    mkdir -p "$(dirname "$from")"
                    mv "$to" "$from"
                fi
                ;;
            ARCHIVE_TGZ)
                log "skip undo of archive ($from); manual restore from $to"
                ;;
        esac
    done
    ok "Rollback complete"
    exit 0
fi

[[ -f "$PLAN" ]] || { err "Plan not found: $PLAN. Copy plan.template.yml → plan.yml and edit it."; exit 1; }

JOURNAL="$JOURNAL_DIR/$(date +%Y%m%d-%H%M%S).log"
[[ "$MODE" == "execute" ]] && : > "$JOURNAL"

log "Mode: $MODE"
log "Plan: $PLAN"
[[ "$MODE" == "execute" ]] && log "Journal: $JOURNAL"

# ---------- Parse YAML (constrained subset) ----------
# Output: section\x1ffrom\x1fto\x1faction\x1fapproved\x1freason\x1fpath_or_suggested
# We use \x1f (unit separator) so empty fields are not collapsed by `read`.
parse_plan() {
    awk -v SEP=$'\x1f' '
    function strip(s) { gsub(/^[[:space:]]+|[[:space:]]+$/, "", s); gsub(/^"|"$/, "", s); return s }
    /^[a-z_]+:[[:space:]]*$/ {
        if (have) emit()
        have = 0
        section = $0; sub(/:.*/, "", section); next
    }
    /^[[:space:]]*#/ { next }
    /^[[:space:]]*-[[:space:]]/ {
        if (have) emit()
        have = 1; from=""; to=""; action="move"; approved="false"; reason=""; path=""; suggested=""
        line = $0
        sub(/^[[:space:]]*-[[:space:]]/, "", line)
        process_kv(line)
        next
    }
    /^[[:space:]]+[a-z_]+:[[:space:]]*/ {
        process_kv($0); next
    }
    END { if (have) emit() }
    function process_kv(l,    k,v,colon) {
        sub(/^[[:space:]]+/, "", l)
        colon = index(l, ":")
        if (colon == 0) return
        k = substr(l, 1, colon-1)
        v = strip(substr(l, colon+1))
        if (k == "from") from=v
        else if (k == "to") to=v
        else if (k == "action") action=v
        else if (k == "approved") approved=v
        else if (k == "reason") reason=v
        else if (k == "path") path=v
        else if (k == "suggested") suggested=v
    }
    function emit() {
        printf "%s%s%s%s%s%s%s%s%s%s%s%s%s\n",
            section, SEP, from, SEP, to, SEP, action, SEP, approved, SEP, reason, SEP,
            (path != "" ? path : suggested)
    }
    ' "$1"
}

# Counters
moves_total=0; moves_done=0; moves_skipped=0; moves_failed=0
deletes_total=0; deletes_done=0
assets_total=0; assets_done=0
security_total=0

run_move() {
    local from_rel="$1" to_rel="$2" reason="$3"
    local from_abs="$PROJECTS_ROOT/$from_rel"
    local to_abs="$PROJECTS_ROOT/$to_rel"

    if [[ ! -e "$from_abs" ]]; then
        warn "skip (source missing): $from_rel"
        return 1
    fi
    if [[ -e "$to_abs" ]]; then
        warn "skip (target exists): $to_rel"
        return 1
    fi

    if [[ "$MODE" == "execute" ]]; then
        mkdir -p "$(dirname "$to_abs")"
        mv "$from_abs" "$to_abs"
        printf '%s\tMOVE\t%s\t%s\n' "$(date -u +%FT%TZ)" "$from_abs" "$to_abs" >> "$JOURNAL"
    fi

    printf '  %s%s%s → %s  %s(%s)%s\n' \
        "$C_GRN" "$from_rel" "$C_RST" "$to_rel" \
        "$C_DIM" "$reason" "$C_RST"
    return 0
}

run_delete() {
    local path_rel="$1" reason="$2"
    local path_abs="$PROJECTS_ROOT/$path_rel"
    [[ -e "$path_abs" ]] || { warn "skip (missing): $path_rel"; return 1; }

    # Archive non-empty paths first
    if [[ -d "$path_abs" ]] && [[ -n "$(ls -A "$path_abs" 2>/dev/null)" ]]; then
        local tgz="$PROJECTS_ROOT/_archive/_deleted/${path_rel//\//_}.tgz"
        if [[ "$MODE" == "execute" ]]; then
            mkdir -p "$(dirname "$tgz")"
            tar -czf "$tgz" -C "$PROJECTS_ROOT" "$path_rel"
            printf '%s\tARCHIVE_TGZ\t%s\t%s\n' "$(date -u +%FT%TZ)" "$path_abs" "$tgz" >> "$JOURNAL"
        fi
        printf '  %sARCHIVE+DELETE%s %s → %s  %s(%s)%s\n' \
            "$C_YLW" "$C_RST" "$path_rel" "${tgz#"$PROJECTS_ROOT/"}" \
            "$C_DIM" "$reason" "$C_RST"
    else
        printf '  %sDELETE%s %s  %s(%s)%s\n' \
            "$C_RED" "$C_RST" "$path_rel" "$C_DIM" "$reason" "$C_RST"
    fi

    if [[ "$MODE" == "execute" ]]; then
        rm -rf "$path_abs"
        printf '%s\tDELETE\t%s\t-\n' "$(date -u +%FT%TZ)" "$path_abs" >> "$JOURNAL"
    fi
    return 0
}

# ---------- Process plan ----------
log "Parsing plan…"
echo
echo "=== MOVES ==="
while IFS=$'\x1f' read -r section from to action approved reason extra; do
    case "$section" in
        moves)
            moves_total=$((moves_total+1))
            if [[ "$approved" != "true" ]]; then
                moves_skipped=$((moves_skipped+1))
                continue
            fi
            if run_move "$from" "$to" "$reason"; then
                moves_done=$((moves_done+1))
            else
                moves_failed=$((moves_failed+1))
            fi
            ;;
    esac
done < <(parse_plan "$PLAN")

echo
echo "=== DELETES ==="
while IFS=$'\x1f' read -r section from to action approved reason extra; do
    case "$section" in
        deletes)
            deletes_total=$((deletes_total+1))
            [[ "$approved" == "true" ]] || continue
            run_delete "$extra" "$reason" && deletes_done=$((deletes_done+1)) || true
            ;;
    esac
done < <(parse_plan "$PLAN")

echo
echo "=== ASSETS ==="
while IFS=$'\x1f' read -r section from to action approved reason extra; do
    case "$section" in
        assets)
            assets_total=$((assets_total+1))
            [[ "$approved" == "true" ]] || continue
            run_move "$from" "$to" "${reason:-asset}" && assets_done=$((assets_done+1)) || true
            ;;
    esac
done < <(parse_plan "$PLAN")

echo
echo "=== SECURITY (review only, never auto-acted) ==="
while IFS=$'\x1f' read -r section from to action approved reason extra; do
    case "$section" in
        security)
            security_total=$((security_total+1))
            printf '  %s%s%s — %s\n' "$C_RED" "$extra" "$C_RST" "$reason"
            ;;
    esac
done < <(parse_plan "$PLAN")

echo
log "Summary:"
printf '  moves:    %d/%d done, %d skipped (not approved), %d failed\n' \
    "$moves_done" "$moves_total" "$moves_skipped" "$moves_failed"
printf '  deletes:  %d/%d done\n' "$deletes_done" "$deletes_total"
printf '  assets:   %d/%d done\n' "$assets_done" "$assets_total"
printf '  security: %d alerts (manual action required)\n' "$security_total"

if [[ "$MODE" == "dry-run" ]]; then
    warn "Dry-run mode — nothing changed. Run with --execute to apply."
else
    ok "Done. Journal: $JOURNAL"
    log "Updating ~/Projects/README.md"
    "$SCRIPT_DIR/gen-readme.sh" || warn "gen-readme.sh failed"
    log "Regenerating symlink farm"
    "$SCRIPT_DIR/sync-symlinks.sh" || warn "sync-symlinks.sh failed"
    log "Updating zellij root_dirs"
    "$SCRIPT_DIR/update-zellij-config.sh" || warn "update-zellij-config.sh failed"
fi

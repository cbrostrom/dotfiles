#!/usr/bin/env bash
# Generate plan.template.yml from _inventory.json
# Applies "Option A klient-først" rules. All moves default to approved: false.
#
# Usage: plan-gen.sh <inventory.json>

set -euo pipefail

if (( BASH_VERSINFO[0] < 4 )); then
    for _b in /opt/homebrew/bin/bash /usr/local/bin/bash; do
        [[ -x "$_b" ]] && exec "$_b" "$0" "$@"
    done
    echo "${0##*/}: bash 4+ required (found $BASH_VERSION)" >&2; exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

INPUT="${1:?usage: plan-gen.sh <inventory.json>}"
[[ -f "$INPUT" ]] || { err "Input not found: $INPUT"; exit 1; }

# Known client directory patterns (lowercase target names)
declare -A CLIENT_MAP=(
    [Alustre]=alustre [alustre]=alustre
    [Brown-Forman]=brown-forman
    [Carlsberg]=carlsberg
    [Dilling]=dilling
    [Ecco]=ecco
    [Fiskars]=fiskars
    [Flexii]=flexii
    [Forman]=forman
    [LEO]=leo
    [Masdar]=masdar
    [PlanetNusa]=planetnusa
    [PostNord]=postnord
    [PSG]=psg
    [WPP]=wpp
    [tine-k]=tine-k
    [tinek]=tine-k
    [themelio]=themelio
)

# Strip common AKQA prefix from repo basename
strip_akqa_prefix() {
    local n="$1"
    n="${n#akqa-dk-}"
    n="${n#akqa-den-}"
    n="${n#akqa-}"
    echo "$n"
}

# Detect client from path or name; outputs "client|stripped-repo-name" or empty
detect_client() {
    local path="$1" name="$2"
    local parts segments=()
    IFS='/' read -ra segments <<< "$path"

    # 1. Direct parent under Clients/ or Shopify/
    if [[ "${segments[0]}" == "Clients" || "${segments[0]}" == "Shopify" ]] && [[ ${#segments[@]} -ge 3 ]]; then
        local maybe="${segments[1]}"
        if [[ -n "${CLIENT_MAP[$maybe]:-}" ]]; then
            local last="${segments[-1]}"
            local stripped_last
            stripped_last=$(strip_akqa_prefix "$last")
            # Also strip "<client>-" prefix if present, e.g. alustre-web → web
            local cl="${CLIENT_MAP[$maybe]}"
            stripped_last="${stripped_last#${cl}-}"
            [[ -z "$stripped_last" ]] && stripped_last="$last"
            echo "${cl}|${stripped_last}"
            return
        fi
    fi

    # 2. Pattern in repo name: akqa-dk-<client>-<rest> or akqa-den-shopify-<client>-*
    local stripped
    stripped=$(strip_akqa_prefix "$name")
    # Try first segment as client
    local first="${stripped%%-*}"
    if [[ -n "${CLIENT_MAP[$first]:-}" ]]; then
        local rest="${stripped#*-}"
        [[ "$rest" == "$stripped" ]] && rest=""
        [[ -z "$rest" ]] && rest="$first"
        echo "${CLIENT_MAP[$first]}|$rest"
        return
    fi

    # akqa-den-shopify-<client>-...
    if [[ "$stripped" =~ ^shopify-([a-z]+)-(.+)$ ]]; then
        local c="${BASH_REMATCH[1]}" r="${BASH_REMATCH[2]}"
        if [[ -n "${CLIENT_MAP[$c]:-}" ]]; then
            echo "${CLIENT_MAP[$c]}|$r"
            return
        fi
    fi

    echo ""
}

# Sandbox indicator words in name
is_sandbox() {
    local n="$1"
    [[ "$n" =~ -test$ ]] && return 0
    [[ "$n" =~ ^test- ]] && return 0
    [[ "$n" == "test" ]] && return 0
    [[ "$n" =~ boilerplate ]] && return 0
    [[ "$n" =~ template ]] && return 0
    [[ "$n" =~ -starter$ ]] && return 0
    return 1
}

# Build maps: name + remote per path. Use \x1f (unit separator) to avoid IFS collapse.
declare -A PATH_TO_REMOTE
declare -A PATH_TO_NAME

while IFS=$'\x1f' read -r path name remote; do
    PATH_TO_NAME[$path]=$name
    PATH_TO_REMOTE[$path]=$remote
done < <(jq -r '.repos[] | [.path, .name, .remote] | join("\u001f")' "$INPUT")

# Identify duplicate remotes (same URL → multiple paths) via jq.
declare -A DUPLICATE_PATHS
while IFS=$'\x1f' read -r winner loser; do
    [[ -z "$loser" ]] && continue
    DUPLICATE_PATHS[$loser]="duplicate of $winner (same remote)"
done < <(jq -r '
    .repos
    | map(select(.remote != "" and .remote != null))
    | group_by(.remote)
    | map(select(length > 1))
    | .[]
    | (sort_by(.path)) as $g
    | $g[1:][] | "\($g[0].path)\u001f\(.path)"
' "$INPUT")

# Header
cat <<EOF
# Projects cleanup plan — generated $(date)
#
# Edit this file: set 'approved: true' on each move you accept.
# Then run: scripts/projects/apply.sh --dry-run
# Then:    scripts/projects/apply.sh --execute
#
# Targets: clients/, internal/, personal/, sandbox/, _assets/, _archive/
# Source paths are relative to ~/Projects/

decisions_needed:
EOF

# Surface specific known questions
jq -r '.problems.duplicates[]' "$INPUT" 2>/dev/null | while read -r d; do
    [[ -z "$d" ]] && continue
    printf '  - %s\n' "$d"
done

cat <<'EOF'

moves:
EOF

# Emit move suggestions
mapfile -t REPO_PATHS < <(jq -r '.repos[].path' "$INPUT")

for path in "${REPO_PATHS[@]}"; do
    name="${PATH_TO_NAME[$path]}"
    remote="${PATH_TO_REMOTE[$path]:-}"
    target=""
    reason=""
    action="move"
    approved="false"

    # Duplicate detection
    if [[ -n "${DUPLICATE_PATHS[$path]:-}" ]]; then
        reason="${DUPLICATE_PATHS[$path]}"
        target="_archive/$(echo "$path" | tr '/' '_')-DUPLICATE"
    else
        # Categorize
        case "$path" in
            Private/*)
                stripped=$(strip_akqa_prefix "$name")
                target="personal/$stripped"
                reason="private → personal/"
                ;;
            Clients/*)
                detected=$(detect_client "$path" "$name")
                if [[ -n "$detected" ]]; then
                    client="${detected%%|*}"
                    repo="${detected##*|}"
                    target="clients/$client/$repo"
                    reason="under client $client"
                else
                    target="clients/_unsorted/$name"
                    reason="needs manual client assignment"
                fi
                ;;
            Shopify/*)
                detected=$(detect_client "$path" "$name")
                if [[ -n "$detected" ]]; then
                    client="${detected%%|*}"
                    repo="${detected##*|}"
                    target="clients/$client/$repo"
                    reason="shopify work for client $client"
                else
                    # Generic shopify (not client-specific)
                    stripped=$(strip_akqa_prefix "$name")
                    if is_sandbox "$stripped"; then
                        target="sandbox/$stripped"
                        reason="shopify sandbox/template"
                    else
                        target="internal/shopify-$stripped"
                        reason="generic shopify, not client-specific"
                    fi
                fi
                ;;
            Internal/*)
                stripped=$(strip_akqa_prefix "$name")
                if is_sandbox "$stripped"; then
                    target="sandbox/$stripped"
                    reason="test/template → sandbox"
                else
                    target="internal/$stripped"
                    reason="internal akqa tool"
                fi
                ;;
            Docker/*)
                stripped=$(strip_akqa_prefix "$name")
                target="sandbox/$stripped"
                reason="docker → sandbox (single-purpose container)"
                ;;
            *)
                target="_unsorted/$path"
                reason="needs manual categorization"
                ;;
        esac
    fi

    # Lowercase final target
    target_lc=$(echo "$target" | awk 'BEGIN{FS="/"; OFS="/"} { for(i=1;i<=NF;i++) $i=tolower($i); print }')

    cat <<EOF
  - from: "$path"
    to: "$target_lc"
    action: $action
    approved: $approved
    reason: "$reason"
EOF
done

# Emit empty/loose/security sections
cat <<'EOF'

deletes:
  # Default empty. Add paths here only if you want them removed (apply.sh asks confirmation).
EOF

jq -r '.problems.empty_dirs[]' "$INPUT" 2>/dev/null | while read -r d; do
    [[ -z "$d" ]] && continue
    cat <<EOF
  - path: "$d"
    reason: "empty dir"
    approved: false
EOF
done

cat <<'EOF'

assets:
  # Loose files in category roots → _assets/
EOF

jq -r '.problems.loose_files[]' "$INPUT" 2>/dev/null | while read -r f; do
    [[ -z "$f" ]] && continue
    base=$(basename "$f")
    cat <<EOF
  - from: "$f"
    to: "_assets/$base"
    approved: false
EOF
done

cat <<'EOF'

security:
  # Sensitive files detected. Recommended action: review and either delete or move out of ~/Projects.
EOF

jq -r '.problems.security[]' "$INPUT" 2>/dev/null | while read -r s; do
    [[ -z "$s" ]] && continue
    cat <<EOF
  - path: "$s"
    suggested: "delete or move to ~/.ssh/"
    approved: false
EOF
done

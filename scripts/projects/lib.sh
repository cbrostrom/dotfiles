#!/usr/bin/env bash
# Shared helpers for projects-cleanup-toolkit.

set -euo pipefail

PROJECTS_ROOT="${PROJECTS_ROOT:-$HOME/Projects}"
SYMLINK_ROOT="${SYMLINK_ROOT:-$HOME/.zellij-projects}"
ZELLIJ_CONFIG="${ZELLIJ_CONFIG:-$HOME/dotfiles/.config/zellij/config.kdl}"

EXCLUDE_DIRS=(
    node_modules .git vendor .next dist build target .venv venv
    __pycache__ .turbo .cache .nuxt .svelte-kit .parcel-cache
    coverage .pnpm-store .yarn .gradle .idea .DS_Store
    bower_components .terraform .serverless out
)

C_RED=$'\033[31m'
C_GRN=$'\033[32m'
C_YLW=$'\033[33m'
C_BLU=$'\033[34m'
C_DIM=$'\033[2m'
C_RST=$'\033[0m'

log()   { printf '%s[*]%s %s\n' "$C_BLU" "$C_RST" "$*" >&2; }
ok()    { printf '%s[+]%s %s\n' "$C_GRN" "$C_RST" "$*" >&2; }
warn()  { printf '%s[!]%s %s\n' "$C_YLW" "$C_RST" "$*" >&2; }
err()   { printf '%s[x]%s %s\n' "$C_RED" "$C_RST" "$*" >&2; }
dim()   { printf '%s%s%s\n' "$C_DIM" "$*" "$C_RST" >&2; }

require_cmd() {
    for cmd in "$@"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            err "Missing required command: $cmd"
            exit 1
        fi
    done
}

fd_excludes() {
    local args=()
    for d in "${EXCLUDE_DIRS[@]}"; do
        args+=(-E "$d")
    done
    printf '%s\n' "${args[@]}"
}

repo_size() {
    # Total size on disk (includes node_modules etc.) — useful for cleanup signaling.
    # On macOS, du --exclude is unreliable so we just take the full size.
    local path="$1"
    du -sk "$path" 2>/dev/null | awk '{print $1 * 1024}'
}

repo_size_clean() {
    # Source-only size: skip heavy dirs via fd. Slower but accurate.
    local path="$1"
    fd -t f -H . "$path" \
        -E node_modules -E .git -E vendor -E .next -E dist -E build \
        -E target -E .venv -E venv -E __pycache__ -E .turbo -E .cache \
        -E .nuxt -E .svelte-kit -E .parcel-cache -E coverage \
        -E .pnpm-store -E .yarn -E .gradle \
        -x stat -f%z 2>/dev/null | awk '{s+=$1} END{print s+0}'
}

git_last_commit_iso() {
    local path="$1"
    git -C "$path" log -1 --format=%cI 2>/dev/null || echo ""
}

git_branch() {
    local path="$1"
    git -C "$path" symbolic-ref --short HEAD 2>/dev/null \
        || git -C "$path" rev-parse --short HEAD 2>/dev/null \
        || echo ""
}

git_dirty_count() {
    local path="$1"
    git -C "$path" status --porcelain 2>/dev/null | wc -l | tr -d ' '
}

git_remote_url() {
    local path="$1"
    git -C "$path" config --get remote.origin.url 2>/dev/null || echo ""
}

detect_stack() {
    local p="$1"
    local stacks=()
    [[ -f "$p/package.json" ]] && stacks+=("node")
    [[ -f "$p/Gemfile" ]] && stacks+=("ruby")
    [[ -f "$p/Cargo.toml" ]] && stacks+=("rust")
    [[ -f "$p/go.mod" ]] && stacks+=("go")
    [[ -f "$p/composer.json" ]] && stacks+=("php")
    [[ -f "$p/pyproject.toml" || -f "$p/requirements.txt" ]] && stacks+=("python")
    [[ -f "$p/docker-compose.yml" || -f "$p/docker-compose.yaml" || -f "$p/Dockerfile" ]] && stacks+=("docker")
    compgen -G "$p/*.csproj" >/dev/null 2>&1 && stacks+=("dotnet")
    compgen -G "$p/*.sln" >/dev/null 2>&1 && stacks+=("dotnet-sln")
    [[ -f "$p/config/settings_schema.json" ]] && stacks+=("shopify-theme")
    [[ -f "$p/shopify.app.toml" || -f "$p/shopify.web.toml" ]] && stacks+=("shopify-app")
    [[ -f "$p/astro.config.mjs" || -f "$p/astro.config.ts" ]] && stacks+=("astro")
    [[ -f "$p/next.config.js" || -f "$p/next.config.mjs" || -f "$p/next.config.ts" ]] && stacks+=("nextjs")
    [[ -f "$p/svelte.config.js" ]] && stacks+=("svelte")
    [[ -f "$p/nuxt.config.ts" || -f "$p/nuxt.config.js" ]] && stacks+=("nuxt")
    [[ -f "$p/vite.config.ts" || -f "$p/vite.config.js" ]] && stacks+=("vite")
    [[ -f "$p/remix.config.js" ]] && stacks+=("remix")

    if [[ ${#stacks[@]} -eq 0 ]]; then
        echo "unknown"
    else
        IFS=','; echo "${stacks[*]}"; unset IFS
    fi
}

human_size() {
    local bytes="$1"
    if [[ -z "$bytes" || "$bytes" == "0" ]]; then echo "0B"; return; fi
    awk -v b="$bytes" 'BEGIN{
        s="BKMGT"; i=1;
        while (b>=1024 && i<5) { b/=1024; i++ }
        printf "%.1f%s\n", b, substr(s,i,1)
    }'
}

iso_age_days() {
    local iso="$1"
    [[ -z "$iso" ]] && { echo ""; return; }
    # Strip timezone for portable parsing on macOS (BSD date).
    local clean="${iso%%+*}"; clean="${clean%%-[0-9][0-9]:[0-9][0-9]}"; clean="${clean%Z}"
    local then now
    then=$(date -j -f "%Y-%m-%dT%H:%M:%S" "$clean" +%s 2>/dev/null) || { echo ""; return; }
    now=$(date +%s)
    echo $(( (now - then) / 86400 ))
}

# has_brain <slug>
# Returns 0 if a modular brain dir exists in the vault for this slug.
has_brain() {
    local slug="$1"
    local vault="${VAULT_AI:-$HOME/Vaults/AI}"
    [[ -d "$vault/projects/$slug" ]]
}

# has_codebase <abs_path>
# Returns 0 if CODEBASE.md exists at the repo root.
has_codebase() {
    [[ -f "$1/CODEBASE.md" ]]
}

# infer_category <rel_path>
# Matches CATEGORY_RULES (first match wins). Requires config to be sourced first.
infer_category() {
    local rel="$1"
    if [[ -z "${CATEGORY_RULES+x}" ]]; then echo "unknown"; return; fi
    local rule pattern cat
    for rule in "${CATEGORY_RULES[@]}"; do
        pattern="${rule%%|*}"
        cat="${rule##*|}"
        # shellcheck disable=SC2254
        case "$rel" in $pattern) echo "$cat"; return ;; esac
    done
    echo "unknown"
}

# registry_row <slug> <abs_path> <category> <stack> <brain_yn> <codebase_yn> <flags>
# Prints one markdown table row for projects-registry.md.
registry_row() {
    local slug="$1" abs="$2" cat="$3" stack="$4" brain="$5" codebase="$6" flags="$7"
    printf '| %s | %s | %s | %s | %s | %s | %s |\n' \
        "$slug" "${abs/#$HOME/\~}" "$cat" "$stack" "$brain" "$codebase" "$flags"
}

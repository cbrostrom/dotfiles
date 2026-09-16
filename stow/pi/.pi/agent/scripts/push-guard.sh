#!/usr/bin/env bash
# push-guard — blocks `git push` unless the target repo is push-whitelisted.
# Called by the guard-git-push hook (pi-yaml-hooks, tool.before.bash).
# Exit 2 blocks the command. Exit 0 allows.
#
# Whitelist file: $HOME/.claude/push-whitelist.txt
# One repo root per line (# and blank lines ignored). Entries may be
#   - relative to $HOME ("system/dotfiles")
#   - absolute ("/home/christian/system/dotfiles")
#   - ~ style ("~/dotfiles")
#
# Target-repo resolution order (first whitelisted match wins):
#   1. `git -C <path> ...push`
#   2. first `cd <path>` in the command chain
#   3. the session cwd
#
# Residual risk (accepted): exotic indirection that rewrites paths at runtime
# (env-liberated GIT_DIR, `exec` chains, indirection through helper scripts)
# is not pattern-traced here. Compare pi-permissions.jsonc — that file is
# documentation only; this hook is the actual enforcement.
set -u

payload=$(cat)
cmd=""
if command -v jq >/dev/null 2>&1; then
    cmd=$(printf '%s' "$payload" | jq -r '.tool_args.command // empty' 2>/dev/null)
fi
# Fallback when jq is absent or returns nothing.
[[ -z "${cmd:-}" ]] && cmd="$payload"
[[ -z "$cmd" ]] && exit 0

# Not a git push → allow. Tokenise the command: find a standalone `git`, skip
# option tokens and their values, then require the next token to be `push`.
# Handles: git push, git -C x push, git --no-pager push, git push origin main,
# chains like `git add . && git push`.
#
# Rare false positive (accepted): an argument token literally named "push"
# (e.g. `git show push`) trips the allow/block decision — read inputs, benign.
toks=()
read -ra toks <<<"$(tr ';&|()' '     ' <<<"$cmd")"
pushed=0
n=${#toks[@]}
for ((i = 0; i < n; i++)); do
    [[ "${toks[i]}" == "git" ]] || continue
    j=$((i + 1))
    if [[ "${toks[j]:-}" == "-C" || "${toks[j]:-}" == "--git-dir" ]]; then
        j=$((j + 2))
    fi
    while [[ "${toks[j]:-}" == -* ]]; do
        j=$((j + 1))
    done
    if [[ "${toks[j]:-}" == "push" ]]; then
        pushed=1
        break
    fi
done
[[ "$pushed" -eq 1 ]] || exit 0

whitelist="${PUSH_WHITELIST_FILE:-$HOME/.claude/push-whitelist.txt}"
if [[ ! -r "$whitelist" ]]; then
    echo "[pi-guard] Blocked git push: no push whitelist readable at $whitelist" >&2
    exit 2
fi

is_whitelisted() {
    local top="$1" entry w
    for entry in $(grep -vE '^[[:space:]]*(#|$)' "$whitelist"); do
        case "$entry" in
            '~') w="$HOME" ;;
            '~'/*) w="$HOME/${entry#\~/}" ;;
            /*) w="$entry" ;;
            *) w="$HOME/$entry" ;;
        esac
        w=$(cd "$w" 2>/dev/null && pwd -P) || continue
        if [[ "$top" == "$w" || "$top" == "$w/"* ]]; then
            return 0
        fi
    done
    return 1
}

# Collect candidate repo roots.
candidates=()
if [[ "$cmd" =~ (^|[^-[:alnum:]])-C[[:space:]]+([^[:space:]]+) ]]; then
    candidates+=("${BASH_REMATCH[2]}")
fi
if [[ "$cmd" =~ cd[[:space:]]+([^;&|[:space:]]+) ]]; then
    candidates+=("${BASH_REMATCH[1]}")
fi
# Session cwd only as last resort — an explicit -C/cd in the command is the
# authoritative pushed repo and must not be masked by a whitelisted cwd.
[[ ${#candidates[@]} -eq 0 ]] && candidates+=(".")

allowed=0
for c in "${candidates[@]}"; do
    case "$c" in
        '~') d="$HOME" ;;
        '~'/*) d="$HOME/${c#\~/}" ;;
        /*) d="$c" ;;
        *) d="$PWD/$c" ;;
    esac
    top=$(cd "$d" 2>/dev/null && git rev-parse --show-toplevel 2>/dev/null) || continue
    top=$(cd "$top" 2>/dev/null && pwd -P) || continue
    [[ -z "$top" ]] && continue
    if is_whitelisted "$top"; then
        allowed=1
        break
    fi
done

if [[ "$allowed" -eq 0 ]]; then
    echo "[pi-guard] Blocked git push: repo is not in $whitelist (entries listed there are the only pushable repos)" >&2
    exit 2
fi

exit 0

#!/usr/bin/env bash
# push-guard — blocks release/publish commands, and `git push` unless the
# target repo is push-whitelisted. Shared by Pi and Cursor:
#
#   pi      (default) pi-yaml-hooks tool.before.bash: reads .tool_args.command,
#           exit 2 + stderr blocks, exit 0 allows.
#   cursor  beforeShellExecution: reads .command/.cwd, answers with
#           {"permission": "allow"|"deny", ...} JSON.
#
# Publish commands (npm/pnpm/yarn/bun/cargo publish, gh release create, gh pr
# merge, docker push, ...) are always blocked: the user runs them by hand.
# Quoted strings and heredoc bodies are ignored, so commit messages that
# mention them pass. `--dry-run` is allowed.
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
# is not pattern-traced here.
set -u

mode="${1:-pi}"
payload=$(cat)
cmd=""
if command -v jq >/dev/null 2>&1; then
    cmd=$(printf '%s' "$payload" | jq -r '.tool_args.command // .command // empty' 2>/dev/null)
    if [[ "$mode" == "cursor" ]]; then
        cwd=$(printf '%s' "$payload" | jq -r '.cwd // .workspace_roots[0] // empty' 2>/dev/null)
        [[ -n "$cwd" ]] && cd "$cwd" 2>/dev/null
    fi
fi
# Fallback when jq is absent or returns nothing.
[[ -z "${cmd:-}" && "$mode" != "cursor" ]] && cmd="$payload"

allow() {
    [[ "$mode" == "cursor" ]] && printf '{"permission":"allow"}\n'
    exit 0
}

block() {
    local msg="[agent-guard] $1"
    if [[ "$mode" == "cursor" ]]; then
        jq -cn --arg m "$msg" '{permission: "deny", user_message: $m, agent_message: $m}'
        exit 0
    fi
    echo "$msg" >&2
    exit 2
}

[[ -z "$cmd" ]] && allow

scan=$(printf '%s' "$cmd" | perl -0pe '
    s/<<-?\s*([\x27"]?)(\w+)\1.*?^\s*\2\s*$//gms;
    s/\x27[^\x27]*\x27/Q/g;
    s/"(?:\\.|[^"\\])*"/Q/g;
')
publish_re='(^|[^[:alnum:]_./-])((npm|pnpm|yarn|bun|cargo|vsce|ovsx)([[:space:]]+npm)?[[:space:]]+publish|gh[[:space:]]+release[[:space:]]+(create|upload|edit|delete)|gh[[:space:]]+pr[[:space:]]+merge|docker[[:space:]]+(image[[:space:]]+)?push|twine[[:space:]]+upload|gem[[:space:]]+push)([[:space:]]|$)'
if printf '%s' "$scan" | grep -qE "$publish_re" && ! printf '%s' "$scan" | grep -q -- '--dry-run'; then
    block "Blocked release/publish command; ask the user to run it themselves: $cmd"
fi

# Not a git push → allow. Tokenise the command: find a standalone `git`, skip
# option tokens and their values, then require the next token to be `push`.
# Handles: git push, git -C x push, git --no-pager push, git push origin main,
# chains like `git add . && git push`.
#
# Rare false positive (accepted): an argument token literally named "push"
# (e.g. `git show push`) trips the allow/block decision — read inputs, benign.
toks=()
read -ra toks <<<"$(tr ';&|()' '     ' <<<"$scan")"
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
[[ "$pushed" -eq 1 ]] || allow

whitelist="${PUSH_WHITELIST_FILE:-$HOME/.claude/push-whitelist.txt}"
[[ -r "$whitelist" ]] || block "Blocked git push: no push whitelist readable at $whitelist"

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
    is_whitelisted "$top" && allow
done

block "Blocked git push: repo is not in $whitelist (entries listed there are the only pushable repos)"

#!/usr/bin/env bash
# shell-guard — Cursor beforeShellExecution guard.
#
# Reads {"command", "cwd"} on stdin and answers {"permission": "allow"|"deny"}.
# Blocks:
#   - catastrophic rm -rf on /, ~, /home, /Users
#   - release/publish commands (npm/pnpm/yarn/bun/cargo publish, gh release,
#     gh pr merge, docker push, twine upload, gem push); --dry-run passes
#   - git push unless the target repo is listed in the push whitelist
# Quoted strings and heredoc bodies are ignored, so commit messages pass.
#
# Whitelist: ${PUSH_WHITELIST_FILE:-$HOME/.claude/push-whitelist.txt}, one repo
# root per line ($HOME-relative, absolute, or ~ style; # and blanks ignored).
set -u

payload=$(cat)
command -v jq >/dev/null 2>&1 || { printf '{"permission":"allow"}\n'; exit 0; }
cmd=$(printf '%s' "$payload" | jq -r '.command // empty' 2>/dev/null)
cwd=$(printf '%s' "$payload" | jq -r '.cwd // .workspace_roots[0] // empty' 2>/dev/null)
[[ -n "$cwd" ]] && cd "$cwd" 2>/dev/null

allow() {
    printf '{"permission":"allow"}\n'
    exit 0
}

block() {
    jq -cn --arg m "[cursor-guard] $1" '{permission: "deny", user_message: $m, agent_message: $m}'
    exit 0
}

[[ -z "$cmd" ]] && allow

scan=$(printf '%s' "$cmd" | perl -0pe '
    s/<<-?\s*([\x27"]?)(\w+)\1.*?^\s*\2\s*$//gms;
    s/\x27[^\x27]*\x27/Q/g;
    s/"(?:\\.|[^"\\])*"/Q/g;
')

if printf '%s' "$scan" | grep -qE 'rm[[:space:]]+-[a-zA-Z]*[rR][a-zA-Z]*f?[a-zA-Z]*[[:space:]]+(--no-preserve-root[[:space:]]+)?(/|/\*|~|~/|~/\*|\$HOME/?|(/home|/Users)(/[^/[:space:]]+)?/?\*?)([[:space:]]|$)'; then
    block "Blocked catastrophic rm: $cmd"
fi

publish_re='(^|[^[:alnum:]_./-])((npm|pnpm|yarn|bun|cargo|vsce|ovsx)([[:space:]]+npm)?[[:space:]]+publish|gh[[:space:]]+release[[:space:]]+(create|upload|edit|delete)|gh[[:space:]]+pr[[:space:]]+merge|docker[[:space:]]+(image[[:space:]]+)?push|twine[[:space:]]+upload|gem[[:space:]]+push)([[:space:]]|$)'
if printf '%s' "$scan" | grep -qE "$publish_re" && ! printf '%s' "$scan" | grep -q -- '--dry-run'; then
    block "Blocked release/publish command; ask the user to run it themselves: $cmd"
fi

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

candidates=()
if [[ "$cmd" =~ (^|[^-[:alnum:]])-C[[:space:]]+([^[:space:]]+) ]]; then
    candidates+=("${BASH_REMATCH[2]}")
fi
if [[ "$cmd" =~ cd[[:space:]]+([^;&|[:space:]]+) ]]; then
    candidates+=("${BASH_REMATCH[1]}")
fi
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

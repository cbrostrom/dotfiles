#!/usr/bin/env bash
# git-push-guard.sh — Claude Code PreToolUse:Bash hook
#
# Blocks publish/push commands (git push, gh release create, npm publish, etc.)
# when the repo is NOT in ~/.claude/push-whitelist.txt. Customer/client repos
# stay safe by default; only repos the user explicitly opts in are allowed.
#
# Whitelist file format: one path per line, supports ~ expansion.
# Path matches if cwd is the path itself or a subdirectory.

set -euo pipefail

if ! command -v jq &>/dev/null; then
    exit 0
fi

INPUT=$(cat)
CMD=$(echo "$INPUT" | jq -r '.tool_input.command // empty')
CWD=$(echo "$INPUT" | jq -r '.cwd // empty')
[[ -z "$CWD" ]] && CWD="$PWD"

if [[ -z "$CMD" ]]; then
    exit 0
fi

# Strip leading env-var assignments (RTK style) for matching.
STRIPPED=$(echo "$CMD" | sed -E 's/^([A-Za-z_][A-Za-z0-9_]*=[^ ]* +)+//')

# Strip leading `rtk ` wrapper so `rtk git push` matches the same rule.
case "$STRIPPED" in
    rtk\ *) STRIPPED="${STRIPPED#rtk }" ;;
esac

# Detect publish-style commands. Match start of the (potentially stripped) command.
is_publish=false
case "$STRIPPED" in
    git\ push|git\ push\ *) is_publish=true ;;
    git\ *push*) # also catch `git -C foo push ...`
        if echo "$STRIPPED" | grep -qE '\bpush\b'; then is_publish=true; fi ;;
    gh\ release\ create*|gh\ release\ delete*) is_publish=true ;;
    gh\ pr\ merge*) is_publish=true ;;
    npm\ publish*|pnpm\ publish*|yarn\ publish*|bun\ publish*) is_publish=true ;;
    cargo\ publish*) is_publish=true ;;
esac

if ! $is_publish; then
    exit 0
fi

WHITELIST="${CLAUDE_PUSH_WHITELIST:-$HOME/.claude/push-whitelist.txt}"

# Resolve cwd to absolute, expanded path.
REAL_CWD=$(cd "$CWD" 2>/dev/null && pwd -P || echo "$CWD")

allowed=false
if [[ -f "$WHITELIST" ]]; then
    while IFS= read -r raw || [[ -n "$raw" ]]; do
        line="${raw%%#*}"
        line="${line#"${line%%[![:space:]]*}"}"
        line="${line%"${line##*[![:space:]]}"}"
        [[ -z "$line" ]] && continue
        # Expand ~ → $HOME without invoking eval.
        # shellcheck disable=SC2088
        case "$line" in
            "~") expanded="$HOME" ;;
            "~/"*) expanded="$HOME/${line#"~/"}" ;;
            *) expanded="$line" ;;
        esac
        # Resolve symlinks if path exists; otherwise use as-is.
        if [[ -e "$expanded" ]]; then
            expanded=$(cd "$expanded" 2>/dev/null && pwd -P || echo "$expanded")
        fi
        if [[ "$REAL_CWD" == "$expanded" || "$REAL_CWD" == "$expanded"/* ]]; then
            allowed=true
            break
        fi
    done < "$WHITELIST"
fi

if $allowed; then
    exit 0
fi

REASON="Push/publish blocked by git-push-guard: '$REAL_CWD' not in $WHITELIST. Customer/client repos must never be pushed automatically. If this is your own repo, add it to the whitelist; otherwise ask the user to push manually."

jq -n --arg reason "$REASON" '{
    "hookSpecificOutput": {
        "hookEventName": "PreToolUse",
        "permissionDecision": "deny",
        "permissionDecisionReason": $reason
    }
}'

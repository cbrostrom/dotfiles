#!/usr/bin/env bash
# time-estimate-gate.sh — enforce token-usage estimates over minutes/hours in PI
# Source of truth: ~/dotfiles/.agents/AGENTS.md → Estimates and sparring.
#
# Two subcommands, wired as pi-yaml-hooks actions:
#
#   detect   (session.idle)    Reads hook JSON on stdin (PI_SESSION_ID). Scans the
#                              last assistant text message in the session JSONL
#                              for time-estimate patterns (e.g. "~30-45 min",
#                              "2 hours"). On violation writes a flag file and
#                              warns in the hook log.
#
#   consume  (user.prompt.submit)  If a violation flag exists, emits a short
#                              correction note on stdout (status: success) with
#                              nothing else — pi-yaml-hooks injects that stdout
#                              as system context for the new turn, so the model
#                              self-corrects. Deletes the flag (one-shot).
#
# Never blocks or errors the agent loop: all failures are silent no-ops.
set -u
FLAG_DIR="${TMPDIR:-/tmp}/pi-time-estimate-gate"
SESSIONS_DIR="$HOME/.pi/agent/sessions"

# Time-estimate patterns: "~30-45 min", "(~2 hours)", "5 minutes", "30-45m", "1.5h"
# Guarded by word boundaries; decimals allowed for hours.
PATTERN='~?[0-9]+([.,][0-9]+)?(-|–)?[0-9]*[[:space:]]*(min(ute)?s?|hours?|hrs?|h)[[:space:])]*[).,]?\b'
# Narrowed to avoid false positives on "h": require min/hour words, bare "h" only after digits+space
PATTERN_STRICT='~?[0-9]+(-|–)?[0-9]*[[:space:]]*(min(ute)?s?|hours?|hrs?)\b|~?[0-9]+([.,][0-9]+)?[[:space:]]*h(ours)?\b'

flagfile() {
    mkdir -p "$FLAG_DIR" 2>/dev/null
    echo "$FLAG_DIR/$1.flag"
}

cmd_detect() {
    sid="${PI_SESSION_ID:-}"
    [[ -z "$sid" ]] && exit 0

    # Locate the session JSONL by id in the sessions tree.
    f=$(fd -t f --hidden -e jsonl "$sid" "$SESSIONS_DIR" 2>/dev/null | head -1)
    [[ -z "$f" || ! -f "$f" ]] && exit 0

    # Extract the last assistant message text blocks (requires jq).
    command -v jq >/dev/null 2>&1 || exit 0
    last_assistant=$(jq -r '
    select(.type=="message" and .message.role=="assistant") |
    [.message.content[]? | select(.type=="text") | .text] | join("\n")
  ' "$f" 2>/dev/null | tail -n 400)

    [[ -z "$last_assistant" ]] && exit 0

    if printf '%s' "$last_assistant" | grep -qiE "$PATTERN_STRICT"; then
        ff="$(flagfile "$sid")"
        printf 'violation\n' >"$ff" 2>/dev/null
        echo "[time-estimate-gate] violation detected in session ${sid}" >&2
        echo "violation" >&2
    fi
    exit 0
}

cmd_consume() {
    sid="${PI_SESSION_ID:-}"
    [[ -z "$sid" ]] && exit 0
    ff="$(flagfile "$sid")"
    [[ -f "$ff" ]] || exit 0
    rm -f "$ff" 2>/dev/null
    cat <<EOF
status: success
[time-estimate-gate] The previous assistant message in this session contained a
TIME estimate (minutes/hours). Agent policy forbids time estimates unless the
user explicitly asked for hours. In this turn, restate any effort framing as
token-usage estimates (context size, read/write volume) plus complexity
(LoC, files/branches touched) and risk surface. If a plan step list used
"~30-45 min" style estimates, restate that line with token estimates now.
EOF
    exit 0
}

case "${1:-}" in
    detect) cmd_detect ;;
    consume) cmd_consume ;;
    *) exit 0 ;;
esac

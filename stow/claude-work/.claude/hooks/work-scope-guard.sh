#!/usr/bin/env bash
# UserPromptSubmit: never blocks. In paths shared with pi, adds a drift-awareness note once per session.
# Escape hatch (set by you, in your shell): CC_SCOPE_GUARD_DISABLE=1
[[ "${CC_SCOPE_GUARD_DISABLE:-}" == "1" ]] && exit 0
payload=$(cat)
sid=$(printf '%s' "$payload" | jq -r '.session_id // "nosession"' 2>/dev/null)
mkdir -p "${TMPDIR:-/tmp}/agent-hooks"
stamp="${TMPDIR:-/tmp}/agent-hooks/cc-scope-note-$sid"
[[ -f "$stamp" ]] && exit 0
: >"$stamp"
cwd=$(printf '%s' "$payload" | jq -r '.cwd // empty' 2>/dev/null)
[[ -z "$cwd" ]] && cwd="$PWD"
lc=$(printf '%s' "$cwd" | tr '[:upper:]' '[:lower:]')
home=$(printf '%s' "$HOME" | tr '[:upper:]' '[:lower:]')
for d in .pi Projects/private/pi-extensions dotfiles; do
  p="$home/$(printf '%s' "$d" | tr '[:upper:]' '[:lower:]')"
  if [[ "$lc" == "$p" || "$lc" == "$p/"* ]]; then
    jq -n --arg c "[cc-guard] $cwd is shared with pi. Avoid drift: don't change pi config, shared skills or agent policy unless asked, and call out any change that affects pi." \
      '{hookSpecificOutput:{hookEventName:"UserPromptSubmit",additionalContext:$c}}'
    exit 0
  fi
done
exit 0

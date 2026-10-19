#!/bin/bash
# ssh-guard: block unbounded/never-exiting ssh commands in tool calls.
# Motivation: agent opened an infinite prompt loop by running
# `ssh monsterbro 'wscript.exe ...'` (and is `sleep`) inside ctx/bash tools
# with no timeout — interactive/never-exiting remote programs hang the tool
# call forever and the Paseo cancel path cannot recover (hard-delete needed).
#
# Usage: ssh-guard.sh <bash|ctx_execute|ctx_batch_execute>
#   Reads the pi-yaml-hooks JSON payload on stdin.
#   exit 2 = block (message on stderr), 0 = allow.
set -u
tool="${1:-bash}"
payload=$(cat)

case "$tool" in
  bash)
    cmd=$(printf '%s' "$payload" | jq -r '.tool_args.command // empty' 2>/dev/null)
    tool_timeout=""
    ;;
  ctx_execute)
    cmd=$(printf '%s' "$payload" | jq -r '.tool_args.code // empty' 2>/dev/null)
    tool_timeout=$(printf '%s' "$payload" | jq -r '.tool_args.timeout // empty' 2>/dev/null)
    ;;
  ctx_batch_execute)
    cmd=$(printf '%s' "$payload" | jq -r '[.tool_args.commands[]?.command // empty] | join("\n")' 2>/dev/null)
    tool_timeout=$(printf '%s' "$payload" | jq -r '.tool_args.timeout // empty' 2>/dev/null)
    ;;
  *) exit 0 ;;
esac
[[ -z "$cmd" ]] && exit 0
echo "$cmd" | grep -qE '\b(ssh|wsl|wsl\.exe)\b' || exit 0

# 1) Never-exiting remote programs (Windows host + Unix variants),
#    triggered per-line and only when the line drives an ssh/wsl invocation.
while IFS= read -r line; do
  [[ -n "$line" ]] || continue
  echo "$line" | grep -qE '\b(ssh|wsl|wsl\.exe)\b' || continue
  echo "$line" | grep -qE 'wscript|cscript|mshta|sleep +infinity|tail +-f|bash +-i|ssh +-t\b' \
    && { echo "[ssh-guard] never-exiting remote program (wscript/cscript/mshta/sleep infinity/tail -f/interactive shell/forced tty) over ssh/wsl — bound it remotely ('timeout <n> <cmd>', 'cmd /c <n> <cmd>') or make it exit. This pattern already orphaned a Paseo agent (unrecoverable cancel bug)." >&2; exit 2; }
done <<< "$(printf '%s\n' "$cmd")"

# 2) ssh must be connect-bounded: per-invocation ConnectTimeout, unless the
#    tool call itself carries a timeout (ctx tools). Checked per command
#    (not per line) so multi-line heredocs/messages that merely mention ssh
#    alongside a real bounded invocation don't false-block.
if [[ "$tool" != bash && -n "$tool_timeout" ]]; then
  exit 0
fi
if echo "$cmd" | grep -qE 'ssh '; then
  if ! echo "$cmd" | grep -qE 'ConnectTimeout=[0-9]+'; then
    echo "[ssh-guard] ssh without ConnectTimeout and no tool timeout: add '-o ConnectTimeout=10' to each ssh (remote command as arg, no tty, no interactive shell). ssh over SSH hangs forever in RPC tools." >&2
    exit 2
  fi
fi
exit 0

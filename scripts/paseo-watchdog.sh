#!/bin/bash
# paseo-watchdog.sh — kill hung shell commands spawned by Paseo-managed pi agents.
#
# Scenario: a pi agent run hangs on a shell tool call that never returns.
# The pi process is wedged waiting on it, so Paseo cancel/stop fails with
# "active run cancellation was not acknowledged". Killing the SHELL (not the
# pi process) makes the tool call return, the run unwinds, and cancel works.
#
# Scope-shrinking rules (non-breaking by design):
#   1. Only pi processes whose parent is the Paseo Daemon are watched.
#   2. Only sh/bash/zsh children are candidates.
#   3. Known long-lived infrastructure children are exempt.
#   4. Only candidates older than THRESHOLD are killed.
#
# Config via environment (defaults shown):
#   THRESHOLD_PASEO_WATCHDOG=900   seconds before a shell child is considered hung
# Plist: com.christian.paseo-watchdog (launchd StartInterval re-runs this script).

set -u
THRESHOLD=${THRESHOLD_PASEO_WATCHDOG:-900}
DRY_RUN=${DRY_RUN_PASEO_WATCHDOG:-0}
LOG="${HOME}/Library/Logs/paseo-watchdog.log"
mkdir -p "$(dirname "$LOG")"

# Infrastructure children that may live long and must never be killed.
EXEMPT_PATTERNS='context-mode|caffeinate|higgins|server\.bundle|node_repl|cua_repl|higgins-venv|launchctl|watchexec|fswatch|vite|turbopack'

log() { printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >>"$LOG"; }

# etime ([[dd-]hh:]mm:ss) -> seconds
etime_to_sec() {
  local t=$1
  local d=0 h=0 m=0 s=0
  case "$t" in
    *-*) d=${t%%-*}; t=${t#*-} ;;
  esac
  r="${t//:/ }"
  # shellcheck disable=SC2086
  set -- $r
  case $# in
    1) s=$1 ;;
    2) m=$1; s=$2 ;;
    3) h=$1; m=$2; s=$3 ;;
  esac
  echo $(( d*86400 + h*3600 + m*60 + s ))
}

charged=0
# pi processes whose parent is the Paseo Daemon
for pp in $(pgrep -x pi); do
  ppid=$(ps -p "$pp" -o ppid= | tr -d ' ')
  [ -z "$ppid" ] && continue
  pcmd=$(ps -p "$ppid" -o command= 2>/dev/null | head -1)
  case "$pcmd" in
    *Paseo\ Daemon*) ;;
    *) continue ;;
  esac
  for child in $(pgrep -P "$pp" 2>/dev/null); do
    cmd=$(ps -p "$child" -o command= 2>/dev/null | head -1)
    [ -z "$cmd" ] && continue
    case "$cmd" in
      sh*|bash*|zsh*) ;;
      *) continue ;;
    esac
    echo "$cmd" | grep -Eqi "$EXEMPT_PATTERNS" && continue
    secs=$(etime_to_sec "$(ps -p "$child" -o etime= | tr -d ' ')")
    if [ "$secs" -ge "$THRESHOLD" ]; then
      log "${DRY_RUN:+[DRY_RUN] }KILL hung shell pid=$child age=${secs}s parent_pi=$pp cmd=${cmd:0:120}"
      if [ "$DRY_RUN" = "1" ]; then
        continue
      fi
      # kill children (tool pipelines) first, then the shell itself
      pgrep -P "$child" 2>/dev/null | xargs kill -9 2>/dev/null
      kill -9 "$child" 2>/dev/null
      charged=$((charged + 1))
    fi
  done
done

[ "$charged" -gt 0 ] || exit 0
# After killing hung shells, nudge: if a pi process still wedged, leave it to
# the /force-stop plugin or manual reload. We only ever kill shells here.
exit 0

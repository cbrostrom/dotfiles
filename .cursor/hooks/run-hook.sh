#!/usr/bin/env bash
# Cursor hook runner: preserve hook stdout, log only failures/slow hooks.
set -uo pipefail

name="${1:-hook}"
if [[ "${2:-}" != "--" ]]; then
  exit 0
fi
shift 2

log_dir="${XDG_STATE_HOME:-$HOME/.local/state}/cursor-hooks"
log_file="$log_dir/hooks.log"
mkdir -p "$log_dir" 2>/dev/null || true

input_file="$(mktemp "${TMPDIR:-/tmp}/cursor-hook-input.XXXXXX")" || exit 0
stdout_file="$(mktemp "${TMPDIR:-/tmp}/cursor-hook-stdout.XXXXXX")" || exit 0
stderr_file="$(mktemp "${TMPDIR:-/tmp}/cursor-hook-stderr.XXXXXX")" || exit 0
trap 'rm -f "$input_file" "$stdout_file" "$stderr_file"' EXIT HUP INT TERM

cat >"$input_file" 2>/dev/null || true

start_ms="$(python3 - <<'PY' 2>/dev/null || date +%s000
import time
print(int(time.time() * 1000))
PY
)"

"$@" <"$input_file" >"$stdout_file" 2>"$stderr_file"
status=$?

end_ms="$(python3 - <<'PY' 2>/dev/null || date +%s000
import time
print(int(time.time() * 1000))
PY
)"
elapsed_ms=$((end_ms - start_ms))

cat "$stdout_file"

if [[ $status -ne 0 || $elapsed_ms -gt 1000 || -s "$stderr_file" ]]; then
  {
    printf '%s\t%s\tstatus=%s\tms=%s\tcmd=' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$name" "$status" "$elapsed_ms"
    printf '%q ' "$@"
    printf '\n'
    if [[ -s "$stderr_file" ]]; then
      sed 's/^/stderr: /' "$stderr_file" | head -20
    fi
  } >>"$log_file" 2>/dev/null || true
fi

exit "$status"

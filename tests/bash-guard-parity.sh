#!/usr/bin/env bash
# Compare bash-guard (bash) with bash-guard.py over sample commands: decision + timing.
# Usage: tests/bash-guard-parity.sh        (exit 1 on any decision mismatch)
H="$(cd "$(dirname "$0")/.." && pwd)/stow/agents/.agents/hooks"
cmds=(
  'ls -la' 'git status' 'npm install' 'echo format' 'rm -rf /' 'rm -rf ~' 'rm -rf $HOME' 'rm -rf ~/Documents'
  'rm -rf ~/a/b/c' 'rm -rf /tmp/foo' 'rm -r .' 'rm -rf *' 'rm file.txt' '/bin/rm -rf /usr' 'sudo rm -rf /etc'
  'r"m" -rf /' 'echo hi; rm -fr /var' 'rm -rf "$dir"' 'rm --recursive /opt' 'git push origin main'
  'git push --dry-run' 'npm publish' 'gh release create v1' 'ssh host ls' 'ssh -o ConnectTimeout=10 host true'
  'docker ps' 'echo docker' 'sudo docker run x' 'paseo run foo' 'cat release-notes.md' 'echo upload'
)
fail=0
decide() { # script mode json -> "exit|stdout"
  local out rc
  out="$(printf "%s" "$3" | "$1" "$2" 2>/dev/null)"; rc=$?; [[ -n "$out" ]] && out="$(jq -c . <<<"$out")"
  printf '%s|%s' "$rc" "$out"
}
for mode in pi claude; do
  for c in "${cmds[@]}"; do
    json="$(jq -nc --arg c "$c" '{tool_input:{command:$c},cwd:"/tmp"}')"
    a="$(decide "$H/bash-guard.py" "$mode" "$json")"
    b="$(decide "$H/bash-guard" "$mode" "$json")"
    [[ "$a" == "$b" ]] || { printf 'MISMATCH [%s] %s\n  py:   %s\n  bash: %s\n' "$mode" "$c" "$a" "$b"; fail=1; }
  done
done
expect() { # want-exit command
  local json rc v
  json="$(jq -nc --arg c "$2" '{tool_input:{command:$c},cwd:"/tmp"}')"
  for v in bash-guard.py bash-guard; do
    printf '%s' "$json" | "$H/$v" pi >/dev/null 2>&1; rc=$?
    [[ $rc == "$1" ]] || { printf 'EXPECT %s got %s [%s] %s\n' "$1" "$rc" "$v" "$2"; fail=1; }
  done
}
for c in 'xargs rm -rf /' 'ls | xargs -n1 rm -rf' 'find . -exec rm -rf {} +' 'find / -execdir rm -r {} \;' 'find . -delete' \
  'sudo env FOO=1 nice -n 5 rm -rf /etc' 'timeout 5 rm -rf /usr' 'find ~ -exec rm -rf {} +'; do expect 2 "$c"; done
for c in 'find . -name x -print' 'xargs echo' 'find /tmp/x -delete' 'xargs rm file' 'find /tmp/x -exec rm -rf {} +'; do expect 0 "$c"; done
for v in bash-guard.py bash-guard; do
  s=$(date +%s)
  for _ in $(seq 50); do printf '%s' '{"tool_input":{"command":"ls -la"}}' | "$H/$v" pi >/dev/null 2>&1; done
  echo "$v: 50 calls in $(( $(date +%s) - s ))s"
done
echo "parity: $([[ $fail == 0 ]] && echo OK || echo FAIL)"
exit $fail

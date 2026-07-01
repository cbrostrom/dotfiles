#!/usr/bin/env bash
# brain-load.sh — Cursor sessionStart hook
# Calls `kb load <slug>` which emits all 3 tiers: personal + modules + project.
# Output is returned as additional_context for the Cursor agent.
set -uo pipefail

KB="${VAULT_AI:-$HOME/Vaults/AI}/tools/kb"
[[ -x "$KB" ]] || exit 0

# Slug: git repo basename if in a repo, else PWD basename
# (hook stdin may have workspace_roots — try that first)
INPUT="$(cat 2>/dev/null || true)"
WORKSPACE="$(printf '%s' "$INPUT" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('workspace_roots',[''])[0])" 2>/dev/null || true)"
if [[ -n "$WORKSPACE" ]] && [[ "$WORKSPACE" != "/" ]]; then
  SLUG="$(basename "$WORKSPACE")"
elif git rev-parse --git-dir >/dev/null 2>&1; then
  SLUG="$(basename "$(git rev-parse --show-toplevel 2>/dev/null)")"
else
  SLUG="$(basename "$PWD")"
fi

output="$(VAULT_AI="${VAULT_AI:-$HOME/Vaults/AI}" "$KB" load "$SLUG" 2>/dev/null)" || exit 0
[[ -z "$output" ]] && exit 0

python3 -c "import json,sys; print(json.dumps({'additional_context': sys.argv[1]}))" "$output"

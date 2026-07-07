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

# Prepend pending.md if it exists and is newer than current.md (last session not yet reviewed)
VAULT_AI_PATH="${VAULT_AI:-$HOME/Vaults/AI}"
PENDING="${VAULT_AI_PATH}/projects/${SLUG}/pending.md"
CURRENT="${VAULT_AI_PATH}/projects/${SLUG}/current.md"
if [[ -f "$PENDING" ]] && { [[ ! -f "$CURRENT" ]] || [[ "$PENDING" -nt "$CURRENT" ]]; }; then
  pending_content="$(cat "$PENDING" 2>/dev/null || true)"
  if [[ -n "$pending_content" ]]; then
    output="=== UNREVIEWED SESSION (last stop) ===
${pending_content}
=== END UNREVIEWED SESSION ===

${output}"
  fi
fi

python3 -c "import json,sys; print(json.dumps({'additional_context': sys.argv[1]}))" "$output"

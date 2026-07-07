#!/usr/bin/env bash
# brain-load.sh — Cursor sessionStart hook
# Calls `kb load <slug>` and injects the output two ways:
#   1. ~/.cursor/rules/session-brain.mdc  — alwaysApply rule (primary, works today)
#   2. JSON stdout additional_context     — will work when Cursor patches the race-condition
#      bug: https://forum.cursor.com/t/157141
set -uo pipefail

KB="${VAULT_AI:-$HOME/Vaults/AI}/tools/kb"
[[ -x "$KB" ]] || exit 0

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

# Prepend pending.md if newer than current.md (unreviewed last session)
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

# Write to ~/.cursor/rules/session-brain.mdc so Cursor injects it as an always-applied rule.
# Workaround: sessionStart additional_context is silently dropped due to a race condition
# between hook execution and composer handle creation (confirmed Cursor bug).
# Rules with alwaysApply:true are loaded reliably. File is refreshed each sessionStart.
python3 - "$HOME/.cursor/rules/session-brain.mdc" "$output" <<'PY'
import sys, pathlib
rule_path, content = pathlib.Path(sys.argv[1]), sys.argv[2]
rule_path.parent.mkdir(parents=True, exist_ok=True)
rule_path.write_text(
    "---\ndescription: Session brain context (kb load \u2014 auto-generated)\nalwaysApply: true\n---\n\n"
    + content + "\n"
)
PY

# Output JSON additional_context — forward-compat: active when Cursor patches the bug
python3 -c "import json,sys; print(json.dumps({'additional_context': sys.argv[1]}))" "$output"

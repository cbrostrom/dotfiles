#!/usr/bin/env bash
# brain-load.sh — Cursor sessionStart hook
# Calls `kb load <slug>` and writes ~/.cursor/rules/session-brain.mdc (on-demand, not alwaysApply).
# Caps output to avoid multi-KB context tax every session.
# Does NOT echo additional_context — prevents double injection when Cursor fixes the
# sessionStart race (https://forum.cursor.com/t/157141).
set -uo pipefail

KB="${VAULT_AI:-$HOME/Vaults/AI}/tools/kb"
[[ -x "$KB" ]] || exit 0

MAX_CHARS="${KB_LOAD_MAX_CHARS:-6000}"
MAX_PENDING_CHARS="${KB_LOAD_MAX_PENDING_CHARS:-1500}"

INPUT="$(cat 2>/dev/null || true)"
WORKSPACE="$(printf '%s' "$INPUT" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('workspace_roots',[''])[0])" 2>/dev/null || true)"
if [[ -n "$WORKSPACE" ]] && [[ "$WORKSPACE" != "/" ]]; then
  SLUG="$(basename "$WORKSPACE")"
elif git rev-parse --git-dir >/dev/null 2>&1; then
  SLUG="$(basename "$(git rev-parse --show-toplevel 2>/dev/null)")"
else
  SLUG="$(basename "$PWD")"
fi

# Generic / home workspaces: personal gotchas only (no project brain, no module index)
case "$SLUG" in
  empty-window|""|"$USER"|"Users-$USER"|"home")
    output="$(VAULT_AI="${VAULT_AI:-$HOME/Vaults/AI}" "$KB" load personal 2>/dev/null | python3 -c "
import sys
text = sys.stdin.read()
# Keep only PERSONAL block if present
if '=== PERSONAL ===' in text:
    start = text.index('=== PERSONAL ===')
    end = text.find('=== END PERSONAL ===', start)
    if end != -1:
        text = text[start:end + len('=== END PERSONAL ===')]
print(text.strip())
" 2>/dev/null)" || exit 0
    ;;
  *)
    output="$(VAULT_AI="${VAULT_AI:-$HOME/Vaults/AI}" "$KB" load "$SLUG" 2>/dev/null)" || exit 0
    ;;
esac

[[ -z "$output" ]] && exit 0

# Prepend pending.md if newer than current.md (unreviewed last session)
VAULT_AI_PATH="${VAULT_AI:-$HOME/Vaults/AI}"
PENDING="${VAULT_AI_PATH}/projects/${SLUG}/pending.md"
CURRENT="${VAULT_AI_PATH}/projects/${SLUG}/current.md"
if [[ -f "$PENDING" ]] && { [[ ! -f "$CURRENT" ]] || [[ "$PENDING" -nt "$CURRENT" ]]; }; then
  pending_content="$(cat "$PENDING" 2>/dev/null || true)"
  if [[ -n "$pending_content" ]]; then
    if [[ "${#pending_content}" -gt "$MAX_PENDING_CHARS" ]]; then
      pending_content="${pending_content:0:$MAX_PENDING_CHARS}

…(pending.md truncated — review and clear ${PENDING})"
    fi
    output="=== UNREVIEWED SESSION (last stop) ===
${pending_content}
=== END UNREVIEWED SESSION ===

${output}"
  fi
fi

# Hard cap total injection size
if [[ "${#output}" -gt "$MAX_CHARS" ]]; then
  output="${output:0:$MAX_CHARS}

…(session brain truncated at ${MAX_CHARS} chars — kb load --full or read vault for more)"
fi

python3 - "$HOME/.cursor/rules/session-brain.mdc" "$output" <<'PY'
import sys, pathlib
rule_path, content = pathlib.Path(sys.argv[1]), sys.argv[2]
rule_path.parent.mkdir(parents=True, exist_ok=True)
rule_path.write_text(
    "---\ndescription: Session brain context (kb load — auto-generated, on-demand)\nalwaysApply: false\n---\n\n"
    + content + "\n"
)
PY

exit 0

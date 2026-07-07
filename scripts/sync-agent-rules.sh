#!/usr/bin/env bash
# sync-agent-rules.sh — drift detection between core.mdc and AGENTS.md
# Read-only. Exits 0 if clean, 1 if drift detected.

DOTFILES="${DOTFILES_DIR:-$HOME/dotfiles}"
CORE="$DOTFILES/.cursor/rules/core.mdc"
AGENTS="$DOTFILES/AGENTS.md"

fail=0

check_rule() {
  local description="$1"
  local pattern="$2"
  local missing_in=""

  grep -qiE "$pattern" "$CORE"   || missing_in="$missing_in core.mdc"
  grep -qiE "$pattern" "$AGENTS" || missing_in="$missing_in AGENTS.md"

  if [[ -n "$missing_in" ]]; then
    echo "MISSING [$description] in:$missing_in"
    fail=1
  else
    echo "OK      [$description]"
  fi
}

echo "Checking rule sync: core.mdc ↔ AGENTS.md"
echo "---"

check_rule "step by step = text only"     "step by step|text instructions only"
check_rule "push whitelist guard"         "push.*whitelist|push-whitelist"
check_rule "commit attribution (no AI)"   "Co-Authored-By|Signed-off-by|AI attribution"
check_rule "approval gate"                "approval gate|mutating commands"

echo "---"
if [[ $fail -eq 0 ]]; then
  echo "Clean — no drift detected."
else
  echo "Drift detected — review missing rules above."
fi

exit $fail

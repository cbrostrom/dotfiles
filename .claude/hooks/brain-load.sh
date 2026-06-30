#!/usr/bin/env bash
# brain-load.sh — SessionStart hook
# Modular dir (Brains/<slug>/) → INDEX + current + next (non-done items).
# Falls back to single-file Brains/<slug>.md, then .claude/brain.md,
# then ~/.claude/.active-project.
set -uo pipefail

# Platform detection
if grep -qi microsoft /proc/version 2>/dev/null || [[ -n "${WSL_DISTRO_NAME:-}" ]]; then
  VAULT_BRAINS="/mnt/c/Users/christian/Obsidian/Brain/Brains"
else
  VAULT_BRAINS="$HOME/Vaults/AI/brains"
fi

# Slug: git repo basename if in a repo, else PWD basename
if git rev-parse --git-dir >/dev/null 2>&1; then
  SLUG="$(basename "$(git rev-parse --show-toplevel 2>/dev/null)")"
else
  SLUG="$(basename "$PWD")"
fi

MODULAR_DIR="${VAULT_BRAINS}/${SLUG}"
VAULT_BRAIN="${VAULT_BRAINS}/${SLUG}.md"
LOCAL_BRAIN=".claude/brain.md"
ACTIVE_PROJECT_FILE="$HOME/.claude/.active-project"

# ── Modular dir ───────────────────────────────────────────────────────────────
if [[ -d "$MODULAR_DIR" ]]; then
  if [[ "$(uname)" == "Darwin" ]]; then
    MOD="$(stat -f "%Sm" -t "%Y-%m-%d %H:%M" "${MODULAR_DIR}/current.md" 2>/dev/null || true)"
  else
    MOD="$(stat -c "%y" "${MODULAR_DIR}/current.md" 2>/dev/null | cut -d'.' -f1 || true)"
  fi

  echo "=== PROJECT BRAIN LOADED ==="
  echo "Source: ${MODULAR_DIR}/ (modular, last written: ${MOD:-unknown})"
  echo "---"

  [[ -f "${MODULAR_DIR}/INDEX.md" ]] && cat "${MODULAR_DIR}/INDEX.md" && echo ""

  if [[ -f "${MODULAR_DIR}/current.md" ]]; then
    echo "---"
    cat "${MODULAR_DIR}/current.md"
    echo ""
  fi

  if [[ -f "${MODULAR_DIR}/next.md" ]]; then
    echo "---"
    grep -v '\[done:' "${MODULAR_DIR}/next.md" || true
  fi

  echo "=== END PROJECT BRAIN ==="
  exit 0
fi

# ── Legacy single-file ────────────────────────────────────────────────────────
if [ -f "$VAULT_BRAIN" ]; then
  BRAIN="$VAULT_BRAIN"
elif [ -f "$LOCAL_BRAIN" ]; then
  BRAIN="$LOCAL_BRAIN"
elif [ -f "$ACTIVE_PROJECT_FILE" ]; then
  ACTIVE_SLUG="$(tr -d '[:space:]' < "$ACTIVE_PROJECT_FILE")"
  ACTIVE_BRAIN="${VAULT_BRAINS}/${ACTIVE_SLUG}.md"
  [ -f "$ACTIVE_BRAIN" ] && BRAIN="$ACTIVE_BRAIN" || exit 0
else
  exit 0
fi

if [[ "$(uname)" == "Darwin" ]]; then
  MOD="$(stat -f "%Sm" -t "%Y-%m-%d %H:%M" "$BRAIN" 2>/dev/null || true)"
else
  MOD="$(stat -c "%y" "$BRAIN" 2>/dev/null | cut -d'.' -f1 || true)"
fi

cat <<EOF
=== PROJECT BRAIN LOADED ===
Source: ${BRAIN} (last written: ${MOD:-unknown})
$(cat "$BRAIN")
=== END PROJECT BRAIN ===
EOF

exit 0

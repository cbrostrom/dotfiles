#!/usr/bin/env bash
# brain-save-inject.sh — PreCompact + UserPromptSubmit hook
# Injects instruction to write brain before context is lost.
# As PreCompact: always fires.
# As UserPromptSubmit: fires only on /compact or /clear.
set -uo pipefail

if [[ "${HOOK_EVENT_NAME:-}" == "UserPromptSubmit" ]]; then
  INPUT="$(cat)"
  PROMPT="$(printf '%s' "$INPUT" | jq -r '.prompt // empty' 2>/dev/null || true)"
  [ -z "$PROMPT" ] && exit 0
  printf '%s' "$PROMPT" | grep -qE '^\s*/(compact|clear)\b' || exit 0
else
  cat >/dev/null
fi

# Slug: git repo basename if in a repo, else PWD basename
if git rev-parse --git-dir >/dev/null 2>&1; then
  SLUG="$(basename "$(git rev-parse --show-toplevel 2>/dev/null)")"
else
  SLUG="$(basename "$PWD")"
fi

# Platform detection
if grep -qi microsoft /proc/version 2>/dev/null || [[ -n "${WSL_DISTRO_NAME:-}" ]]; then
  VAULT_BRAINS="/mnt/c/Users/christian/Obsidian/Brain/Brains"
else
  VAULT_BRAINS="$HOME/Vaults/AI/projects"
fi

MODULAR_DIR="${VAULT_BRAINS}/${SLUG}"
BRAIN="${VAULT_BRAINS}/${SLUG}.md"
NOW="$(date '+%Y-%m-%d %H:%M')"

# Git snapshot line (optional)
GIT_SNAP=""
if git rev-parse --git-dir >/dev/null 2>&1; then
  GIT_SNAP="$(git diff --stat HEAD 2>/dev/null || git diff --stat HEAD~1 2>/dev/null || true)"
fi

# ── Modular brain dir ─────────────────────────────────────────────────────────
if [[ -d "$MODULAR_DIR" ]]; then
  cat <<EOF
=== KB SAVE REQUIRED ===
Context about to compact/clear. Persist new facts to the vault NOW before proceeding.
Project: ${SLUG} | Timestamp: ${NOW}

Use these commands (each appends — never destructive overwrites):
  kb current "<one-line fact>"   → current.md (≤5 bullets hard cap)
  kb next "<open action>"        → next.md
  kb gotcha "<non-obvious trap>" → gotchas.md
  kb remember                    → full digest: scan sessions + auto-prune/compact

Or write directly (atomic):
  1. ${MODULAR_DIR}/current.md — merge new state; keep ≤5 bullets
  2. ${MODULAR_DIR}/next.md — add new action items; mark done as [done: YYYY-MM-DD]
${GIT_SNAP:+
## Git Snapshot (reference only — do NOT write to file)
${GIT_SNAP}}

After persisting, proceed with the compact/clear.
=== END KB SAVE REQUIRED ===
EOF
  exit 0
fi

# ── Legacy single-file ────────────────────────────────────────────────────────
cat <<EOF
=== KB SAVE REQUIRED ===
Context about to compact/clear. Persist new facts to the vault NOW before proceeding.
Project: ${SLUG} | Timestamp: ${NOW}

Use kb CLI:
  kb current "<one-line fact>"   → current.md
  kb next "<open action>"        → next.md
  kb gotcha "<non-obvious trap>" → gotchas.md
  kb remember                    → full digest + auto-prune/compact
${GIT_SNAP:+
## Git Snapshot (reference only)
${GIT_SNAP}}

After persisting, proceed with the compact/clear.
=== END KB SAVE REQUIRED ===
EOF

exit 0

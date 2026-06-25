#!/usr/bin/env bash
# vault-save.sh — Cursor stop hook
# Lightweight vault nudge after each agent task. Agent self-filters:
# if nothing significant happened, it writes nothing.
set -uo pipefail

# Platform detection
if grep -qi microsoft /proc/version 2>/dev/null || [[ -n "${WSL_DISTRO_NAME:-}" ]]; then
  VAULT_BRAINS="/mnt/c/Users/christian/Obsidian/Brain/Brains"
else
  VAULT_BRAINS="$HOME/Vaults/Brain/Brains"
fi

# Slug from git root, fallback to cwd basename
if git rev-parse --git-dir >/dev/null 2>&1; then
  SLUG="$(basename "$(git rev-parse --show-toplevel 2>/dev/null)")"
else
  SLUG="$(basename "$PWD")"
fi

MODULAR_DIR="${VAULT_BRAINS}/${SLUG}"

# Only nudge when a modular brain dir exists for this project
[[ -d "$MODULAR_DIR" ]] || exit 0

NOW="$(date '+%Y-%m-%d %H:%M')"

cat <<EOF
[vault:${SLUG}] ${NOW} — if this task produced new facts, decisions, or gotchas worth keeping, persist them now (otherwise skip):
  brain current "<fact>"   → current.md
  brain next "<action>"    → next.md
  brain gotcha "<trap>"    → gotchas.md
EOF

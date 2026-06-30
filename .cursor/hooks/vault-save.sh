#!/usr/bin/env bash
# vault-save.sh — Cursor stop hook
# 1. Always appends a zero-token session marker to Inbox/ (agnostic).
# 2. Dumps raw stdin JSON to /tmp/cursor-stop-event.json for inspection.
# 3. Nudges the AI only when a modular brain dir exists for this project.
set -uo pipefail

INPUT="$(cat)"
echo "$INPUT" > /tmp/cursor-stop-event.json

# Platform detection
if grep -qi microsoft /proc/version 2>/dev/null || [[ -n "${WSL_DISTRO_NAME:-}" ]]; then
  VAULT_BRAINS="/mnt/c/Users/christian/Obsidian/Brain/Brains"
  VAULT_INBOX="/mnt/c/Users/christian/Obsidian/Brain/Inbox"
else
  VAULT_BRAINS="$HOME/Vaults/AI/brains"
  VAULT_SESSIONS="$HOME/Vaults/AI/sessions"
fi

# Slug from workspace_roots[0] (reliable), fallback to PWD basename
WORKSPACE="$(echo "$INPUT" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('workspace_roots',[''])[0])" 2>/dev/null || true)"
if [[ -n "$WORKSPACE" ]]; then
  SLUG="$(basename "$WORKSPACE")"
else
  SLUG="$(basename "$PWD")"
fi

TRANSCRIPT="$(echo "$INPUT" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('transcript_path',''))" 2>/dev/null || true)"

NOW="$(date '+%Y-%m-%d %H:%M')"
TODAY="$(date '+%Y-%m-%d')"
HHMM="$(date '+%H%M')"

# ── Zero-token session marker → sessions/ ────────────────────────────────────
INBOX_FILE="${VAULT_SESSIONS}/${TODAY}-${SLUG}-session.md"
if [[ ! -f "$INBOX_FILE" ]]; then
  printf '# Session log: %s — %s\n' "$SLUG" "$TODAY" > "$INBOX_FILE"
  [[ -n "$TRANSCRIPT" ]] && printf 'transcript: %s\n' "$TRANSCRIPT" >> "$INBOX_FILE"
  printf '\n' >> "$INBOX_FILE"
fi
printf '- %s  stop\n' "$HHMM" >> "$INBOX_FILE"

# ── Zero-token TF-IDF summary (runs in background, no AI needed) ──────────────
if [[ -n "$TRANSCRIPT" ]] && command -v session-summarize &>/dev/null; then
  session-summarize "$TRANSCRIPT" "$INBOX_FILE" &>/dev/null &
fi

# ── AI nudge — only when modular brain dir exists ─────────────────────────────
MODULAR_DIR="${VAULT_BRAINS}/${SLUG}"
[[ -d "$MODULAR_DIR" ]] || exit 0

cat <<EOF
[vault:${SLUG}] ${NOW} — if this task produced new facts, decisions, or gotchas worth keeping, persist them now (otherwise skip):
  brain current "<fact>"   → current.md
  brain next "<action>"    → next.md
  brain gotcha "<trap>"    → gotchas.md
EOF

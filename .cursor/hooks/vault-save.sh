#!/usr/bin/env bash
# vault-save.sh — Cursor stop hook
# 1. Writes a zero-token session marker to sessions/YYYY/MM/
# 2. Runs TF-IDF summariser in background (no AI, no tokens)
# 3. Silently runs kb prune + compact for the active slug
# 4. Nudges the AI to persist new facts when a project brain exists
set -uo pipefail

INPUT="$(cat)"
echo "$INPUT" > /tmp/cursor-stop-event.json

KB="${VAULT_AI:-$HOME/Vaults/AI}/tools/kb"

# Platform detection
if grep -qi microsoft /proc/version 2>/dev/null || [[ -n "${WSL_DISTRO_NAME:-}" ]]; then
  VAULT_AI_PATH="/mnt/c/Users/christian/Obsidian/AI"
else
  VAULT_AI_PATH="${VAULT_AI:-$HOME/Vaults/AI}"
fi

VAULT_SESSIONS="${VAULT_AI_PATH}/sessions"
VAULT_PROJECTS="${VAULT_AI_PATH}/projects"

# Slug from workspace_roots[0] (reliable), fallback to git basename, fallback to PWD
WORKSPACE="$(echo "$INPUT" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('workspace_roots',[''])[0])" 2>/dev/null || true)"
if [[ -n "$WORKSPACE" ]] && [[ "$WORKSPACE" != "/" ]]; then
  SLUG="$(basename "$WORKSPACE")"
elif git rev-parse --git-dir >/dev/null 2>&1; then
  SLUG="$(basename "$(git rev-parse --show-toplevel 2>/dev/null)")"
else
  SLUG="$(basename "$PWD")"
fi

TRANSCRIPT="$(echo "$INPUT" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('transcript_path',''))" 2>/dev/null || true)"

TODAY="$(date '+%Y-%m-%d')"
YEAR="$(date '+%Y')"
MONTH="$(date '+%m')"
HHMM="$(date '+%H%M')"
NOW="$(date '+%Y-%m-%d %H:%M')"

# ── Session marker → sessions/YYYY/MM/ ───────────────────────────────────────
SESSION_DIR="${VAULT_SESSIONS}/${YEAR}/${MONTH}"
mkdir -p "$SESSION_DIR" 2>/dev/null || true
SESSION_FILE="${SESSION_DIR}/${TODAY}-${SLUG}-session.md"
if [[ ! -f "$SESSION_FILE" ]]; then
  printf '# Session log: %s — %s\n' "$SLUG" "$TODAY" > "$SESSION_FILE"
  [[ -n "$TRANSCRIPT" ]] && printf 'transcript: %s\n' "$TRANSCRIPT" >> "$SESSION_FILE"
  printf '\n' >> "$SESSION_FILE"
fi
printf -- '- %s  stop\n' "$HHMM" >> "$SESSION_FILE"

# ── Zero-token TF-IDF summary (background, no API) ───────────────────────────
if [[ -n "$TRANSCRIPT" ]] && command -v session-summarize &>/dev/null; then
  session-summarize "$TRANSCRIPT" "$SESSION_FILE" &>/dev/null &
fi

# ── Silent prune + compact (background, idempotent) ──────────────────────────
if [[ -x "$KB" ]]; then
  (
    VAULT_AI="$VAULT_AI_PATH" "$KB" prune "$SLUG" 2>/dev/null
    VAULT_AI="$VAULT_AI_PATH" "$KB" compact "$SLUG" 2>/dev/null
  ) &
fi

# ── AI nudge — only when project brain exists ─────────────────────────────────
MODULAR_DIR="${VAULT_PROJECTS}/${SLUG}"
[[ -d "$MODULAR_DIR" ]] || exit 0

cat <<EOF
[kb:${SLUG}] ${NOW} — if this session produced new facts, decisions, or traps worth keeping, persist them now (otherwise skip):
  kb current "<one-line fact>"   → current.md (≤5 bullets)
  kb next "<open action>"        → next.md
  kb gotcha "<non-obvious trap>" → gotchas.md
  kb remember                    → digest recent sessions + auto-prune/compact
EOF

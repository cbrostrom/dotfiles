#!/usr/bin/env bash
# vault-save.sh — Cursor stop hook
# 1. Writes a zero-token session marker to sessions/YYYY/MM/
# 2. Runs TF-IDF summariser in background (no AI, no tokens)
# 3. Silently runs kb prune + compact for the active slug
# 4. Writes pending.md to project brain (files edited + last state) — picked up by brain-load
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

# ── Write pending.md — deterministic, no AI, picked up by brain-load ──────────
MODULAR_DIR="${VAULT_PROJECTS}/${SLUG}"
[[ -d "$MODULAR_DIR" ]] || exit 0

# Capture git commits from the active workspace (today, last 24h fallback)
GIT_LOG=""
if [[ -n "$WORKSPACE" ]] && git -C "$WORKSPACE" rev-parse --git-dir >/dev/null 2>&1; then
  GIT_LOG="$(git -C "$WORKSPACE" log --oneline --since="today" --format="- %h %s" 2>/dev/null || true)"
  [[ -z "$GIT_LOG" ]] && GIT_LOG="$(git -C "$WORKSPACE" log --oneline --since="24 hours ago" --format="- %h %s" 2>/dev/null || true)"
fi

if [[ -n "$TRANSCRIPT" && -f "$TRANSCRIPT" ]]; then
  python3 - "$TRANSCRIPT" "$MODULAR_DIR/pending.md" "$NOW" "$SESSION_FILE" "$GIT_LOG" <<'PY'
import json, sys, re
from pathlib import Path

transcript_path, out_path, now, session_file = sys.argv[1:5]
git_log = sys.argv[5] if len(sys.argv) > 5 else ""
WRITE_TOOLS = {"Write", "StrReplace", "Delete", "EditNotebook"}
HOME = str(Path.home())

edited, last_state = [], ""
try:
    with open(transcript_path, encoding="utf-8") as fh:
        for raw in fh:
            raw = raw.strip()
            if not raw:
                continue
            try:
                obj = json.loads(raw)
            except ValueError:
                continue
            role = obj.get("role", "")
            content = obj.get("message", {}).get("content", [])
            if not isinstance(content, list):
                continue
            for block in content:
                if not isinstance(block, dict):
                    continue
                if role == "assistant" and block.get("type") == "tool_use":
                    name = block.get("name", "")
                    if name in WRITE_TOOLS:
                        inp = block.get("input") or {}
                        path = inp.get("path") or inp.get("target_notebook", "")
                        if path and path not in edited:
                            edited.append(path)
                elif role == "assistant" and block.get("type") == "text":
                    text = block.get("text", "").strip()
                    if text:
                        last_state = re.sub(r"\s+", " ", re.sub(r"<[^>]+>", " ", text))[:300]
except Exception:
    pass

if not edited and not git_log:
    sys.exit(0)

lines = [
    f"# Pending review — {now}",
    f"_Unreviewed. At session start: promote to current.md/next.md if relevant, then delete._",
]

if git_log:
    lines.append("")
    lines.append("## Commits this session")
    for line in git_log.strip().splitlines():
        lines.append(line)

if edited:
    lines.append("")
    lines.append(f"## Files edited ({len(edited)})")
    for p in edited:
        short = p.replace(HOME, "~")
        lines.append(f"- `{short}`")

if last_state:
    lines.append("")
    lines.append("## Where we left off")
    lines.append(last_state + "…")

lines.append("")
lines.append(f"Full session log: `{session_file.replace(HOME, '~')}`")

Path(out_path).write_text("\n".join(lines) + "\n")
PY
fi

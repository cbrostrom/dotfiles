#!/usr/bin/env bash
# brain-optimise-cheap.sh — SessionStart hook (runs before brain-load.sh)
# Structural-only optimise: no LLM, no content edits except next.md done-strip.
# Idempotent. Exits 0 on no-op (no modular brain dir found).
set -euo pipefail

# Platform detection
if grep -qi microsoft /proc/version 2>/dev/null || [[ -n "${WSL_DISTRO_NAME:-}" ]]; then
  VAULT_BRAINS="/mnt/c/Users/christian/Obsidian/Brain/Brains"
else
  VAULT_BRAINS="$HOME/Vaults/Brain/Brains"
fi

# Slug
if git rev-parse --git-dir >/dev/null 2>&1; then
  SLUG="$(basename "$(git rev-parse --show-toplevel 2>/dev/null)")"
else
  SLUG="$(basename "$PWD")"
fi

BRAIN_DIR="${VAULT_BRAINS}/${SLUG}"
[[ -d "$BRAIN_DIR" ]] || exit 0

TODAY="$(date '+%Y-%m-%d')"

# ── 1. Strip done items >30 days old from next.md ────────────────────────────
NEXT_FILE="${BRAIN_DIR}/next.md"
if [[ -f "$NEXT_FILE" ]]; then
  python3 - "$NEXT_FILE" "$TODAY" <<'PYEOF'
import sys, re, os
from datetime import date, timedelta

path, today_str = sys.argv[1], sys.argv[2]
today = date.fromisoformat(today_str)
cutoff = today - timedelta(days=30)

text = open(path).read()
kept = []
for line in text.splitlines(keepends=True):
    m = re.search(r'\[done:\s*(\d{4}-\d{2}-\d{2})\]', line)
    if m and date.fromisoformat(m.group(1)) <= cutoff:
        continue
    kept.append(line)
result = ''.join(kept)
tmp = path + '.tmp'
with open(tmp, 'w') as f:
    f.write(result)
os.rename(tmp, path)
PYEOF
fi

# ── 2. Roll up history files >30 days old into archive ────────────────────────
HIST_DIR="${BRAIN_DIR}/history"
ARCH_DIR="${BRAIN_DIR}/archive"
mkdir -p "$HIST_DIR" "$ARCH_DIR"

if [[ "$(uname)" == "Darwin" ]]; then
  CUTOFF_DATE="$(date -v-30d '+%Y-%m-%d')"
else
  CUTOFF_DATE="$(date -d '30 days ago' '+%Y-%m-%d')"
fi

for hist_file in "${HIST_DIR}"/[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]-*.md; do
  [[ -f "$hist_file" ]] || continue
  file_date="$(basename "$hist_file" | cut -c1-10)"
  [[ "$file_date" < "$CUTOFF_DATE" ]] || continue

  month="${file_date:0:7}"
  arch_file="${ARCH_DIR}/${month}.md"

  {
    [[ -f "$arch_file" ]] && cat "$arch_file"
    cat "$hist_file"
    echo ""
  } > "${arch_file}.tmp"
  mv "${arch_file}.tmp" "$arch_file"
  rm -f "$hist_file"
done

# ── 3. Regenerate INDEX.md ────────────────────────────────────────────────────
python3 - "$BRAIN_DIR" "$SLUG" <<'PYEOF'
import sys, os
from pathlib import Path

brain_dir, slug = sys.argv[1], sys.argv[2]

def first_content_line(text):
    in_fm = False
    for i, l in enumerate(text.splitlines()):
        if i == 0 and l.strip() == '---':
            in_fm = True
            continue
        if in_fm and l.strip() == '---':
            in_fm = False
            continue
        if in_fm:
            continue
        if l and not l.startswith('#'):
            return l
    return '—'

lines = [f'# Brain index: {slug}']
for fname in ['current.md', 'gotchas.md', 'next.md']:
    fpath = Path(brain_dir) / fname
    if fpath.exists():
        text = fpath.read_text()
        lc = len(text.splitlines())
        first = first_content_line(text)
        lines.append(f'- {fname} ({lc}L) — {first[:60]}')

hist_dir = Path(brain_dir) / 'history'
hist_files = sorted(hist_dir.glob('*.md')) if hist_dir.exists() else []
last_hist = hist_files[-1].stem if hist_files else 'none'
lines.append(f'- history/ — {len(hist_files)} session(s), last {last_hist}')

arch_dir = Path(brain_dir) / 'archive'
arch_files = list(arch_dir.glob('*.md')) if arch_dir.exists() else []
if arch_files:
    lines.append(f'- archive/ — {len(arch_files)} monthly file(s)')

result = '\n'.join(lines) + '\n'
tmp = str(Path(brain_dir) / 'INDEX.md.tmp')
with open(tmp, 'w') as f:
    f.write(result)
os.rename(tmp, str(Path(brain_dir) / 'INDEX.md'))
PYEOF

exit 0

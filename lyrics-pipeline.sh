#!/bin/zsh
# Batch: MP3 → demucs vocals → faster-whisper → .md (or .txt) lyrics next to each file
# Usage: ./lyrics-pipeline.sh [MusicDir] [whisper_model]
# Defaults: MusicDir = ., model = base (use large-v3 for quality, slow on CPU)
# Only processes .mp3. Writes <name>.md (fallback <name>.txt) beside each track.

set -euo pipefail

MUSIC_DIR="${1:-.}"
MODEL="${2:-base}"
VENV="$HOME/venvs/faster-whisper/bin"
WORK_DIR="$MUSIC_DIR/_demucs_work"

"$VENV/python" -c "import demucs, faster_whisper" 2>/dev/null || {
  echo "Missing deps, installing in venv..." >&2
  "$VENV/pip" install faster-whisper demucs
}

mkdir -p "$WORK_DIR/in"

find "$MUSIC_DIR" -type f -iname '*.mp3' -not -path '*/_demucs_work/*' |
while IFS= read -r track; do
  base="$(basename "$track")"
  name="${base%.*}"
  parent="$(dirname "$track")"
  lrc_md="$parent/$name.md"
  lrc_txt="$parent/$name.txt"
  vocals="$WORK_DIR/htdemucs/$name/vocals.wav"

  if [[ -f "$lrc_md" || -f "$lrc_txt" ]]; then
    echo "SKIP (lyrics exist): $track"
    continue
  fi

  echo "=== $track"

  # 1) separate vocals (skip if stem already exists)
  if [[ ! -f "$vocals" ]]; then
    cp "$track" "$WORK_DIR/in/$base"
    (cd "$WORK_DIR" && "$VENV/demucs" -n htdemucs --two-stem=vocals -o "$WORK_DIR" "$WORK_DIR/in/$base")
  fi

  if [[ ! -f "$vocals" ]]; then
    echo "ERROR: no vocals.wav produced for $track" >&2
    continue
  fi

  # 2) transcribe vocals → .md (fallback .txt)
  "$VENV/python" - "$vocals" "$lrc_md" "$lrc_txt" "$MODEL" "$name" <<'PYEOF'
import sys
from faster_whisper import WhisperModel
src, dst_md, dst_txt, model_name, title = sys.argv[1:6]
model = WhisperModel(model_name, device="cpu", compute_type="int8")
segments, _ = model.transcribe(src, vad_filter=True)
lines = []
prev_end = None
for seg in segments:
    text = " ".join(seg.text.split())
    if not text:
        continue
    # heuristic sectioning: new paragraph when gap from previous segment > 4s
    if prev_end is not None and (seg.start - prev_end) > 4.0 and lines:
        lines.append("")  # blank line = section break
    m, s = divmod(int(seg.start), 60)
    lines.append(f"[{m:02d}:{s:02d}] {text}")
    prev_end = seg.end
if not lines:
    print(f"NO LYRICS DETECTED: {src}", file=sys.stderr)
    sys.exit(0)
body = "\n".join(lines).strip() + "\n"
for dst in (dst_md, dst_txt):
    if dst.endswith(".md"):
        content = f"# {title}\n\n{body}"
    else:
        content = body
    try:
        with open(dst, "w") as f:
            f.write(content)
    except OSError:
        continue
PYEOF

  rm -f "$WORK_DIR/in/$base"
  echo "OK → $( [[ -f "$lrc_md" ]] && echo "$lrc_md" || echo "$lrc_txt" )"
done

echo "Done. Stems cached in $WORK_DIR (delete _demucs_work to reclaim space)."

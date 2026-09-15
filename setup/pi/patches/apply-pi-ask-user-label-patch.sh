#!/usr/bin/env bash
# Accept ask_user options[].label in schema validation (models often send label, not title).
# Idempotent; safe to run from setup/pi.sh and after a Pi update.
set -euo pipefail

TARGET="${PI_ASK_USER_INDEX:-$HOME/.pi/agent/npm/node_modules/pi-ask-user/index.ts}"
MARKER="DOTFILES_PATCH: accept label alias"

if [[ ! -f "$TARGET" ]]; then
  echo "[pi-ask-user-patch] skip — not installed ($TARGET)"
  exit 0
fi

if grep -q "$MARKER" "$TARGET"; then
  echo "[pi-ask-user-patch] already applied"
  exit 0
fi

python3 - "$TARGET" "$MARKER" <<'PY'
import sys

path, marker = sys.argv[1], sys.argv[2]
text = open(path, encoding="utf-8").read()

old = """               Type.Object({
                  title: Type.String({ description: "Short title for this option" }),
                  description: Type.Optional(
                     Type.String({ description: "Longer description explaining this option" }),
                  ),
               }),"""

new = f"""               Type.Object({{
                  // {marker}
                  title: Type.Optional(Type.String({{ description: "Short title for this option" }})),
                  label: Type.Optional(Type.String({{ description: "Alias for title (models often send label instead of title)" }})),
                  description: Type.Optional(
                     Type.String({{ description: "Longer description explaining this option" }}),
                  ),
               }}),"""

if old not in text:
    print("[pi-ask-user-patch] ERROR: upstream schema block not found — manual review needed", file=sys.stderr)
    sys.exit(1)

open(path, "w", encoding="utf-8").write(text.replace(old, new, 1))
print("[pi-ask-user-patch] applied label/title schema alias")
PY

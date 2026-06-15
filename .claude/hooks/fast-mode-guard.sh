#!/usr/bin/env bash
# UserPromptSubmit: warn when /fast is typed. Opus = $75/MTok output vs Sonnet $15.
set -uo pipefail

INPUT="$(cat)"
PROMPT="$(printf '%s' "$INPUT" | jq -r '.prompt // empty' 2>/dev/null || true)"
[ -z "$PROMPT" ] && exit 0

printf '%s' "$PROMPT" | grep -qE '^\s*/fast\b' || exit 0

echo '{"systemMessage": "WARNING: /fast switches to Opus (~5x cost). You have a standing rule to never use fast mode. Cancel with Ctrl+C, or type /fast again if truly intentional."}'

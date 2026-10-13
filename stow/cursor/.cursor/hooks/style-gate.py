#!/usr/bin/env python3
"""style-gate: flag mechanical output-style violations and correct them next turn.

Checks the latest assistant reply (code blocks and inline code ignored) for:
time estimates, em-dashes, filler openers, and heavy filler-word use.
Never blocks: detect writes a one-shot flag, consume injects a correction.

  style-gate.py detect    afterAgentResponse (stdin: text, conversation_id)
  style-gate.py consume   postToolUse -> additional_context

All failures are no-ops.
"""
from __future__ import annotations

import json
import os
import re
import sys
import tempfile

FLAG_DIR = os.path.join(os.environ.get("TMPDIR") or tempfile.gettempdir(), "cursor-style-gate")

TIME_RE = re.compile(
    r"~?\d+(?:[-–]\d+)?\s*(?:min(?:ute)?s?|hours?|hrs?)\b|~?\d+(?:[.,]\d+)?\s*h(?:ours)?\b",
    re.I,
)
OPENER_RE = re.compile(
    r"^\W*(great question|good question|sure|certainly|absolutely|of course|happy to help)\b", re.I
)
FILLER_RE = re.compile(r"\b(just|really|basically|actually|simply)\b", re.I)
FILLER_LIMIT = 3


def prose(text: str) -> str:
    text = re.sub(r"```.*?```", "", text, flags=re.S)
    text = re.sub(r"~~~.*?~~~", "", text, flags=re.S)
    return re.sub(r"`[^`\n]*`", "", text)


def violations(text: str) -> list[str]:
    body = prose(text)
    found = []
    if TIME_RE.search(body):
        found.append("time estimate (minutes/hours): restate effort as tokens + complexity (LoC, files, risk)")
    if "\u2014" in body:
        found.append("em-dash: use a comma, colon, parentheses or a new sentence")
    first = next((line for line in body.splitlines() if line.strip()), "")
    if OPENER_RE.search(first):
        found.append("filler opener: start with the answer")
    fillers = len(FILLER_RE.findall(body))
    if fillers >= FILLER_LIMIT:
        found.append(f"filler words ({fillers}x just/really/basically/actually/simply): cut them")
    return found


def flag_path(key: str) -> str:
    return os.path.join(FLAG_DIR, re.sub(r"[^\w.-]", "_", key) + ".flag")


def main() -> None:
    action = sys.argv[1] if len(sys.argv) > 1 else ""
    try:
        payload = json.loads(sys.stdin.read() or "{}")
    except ValueError:
        payload = {}
    key = str(payload.get("conversation_id") or "")

    if action == "detect":
        found = violations(str(payload.get("text") or ""))
        if key and found:
            os.makedirs(FLAG_DIR, exist_ok=True)
            with open(flag_path(key), "w") as f:
                f.write("\n".join(found))
        return

    if action == "consume":
        note = None
        if key:
            try:
                with open(flag_path(key)) as f:
                    found = f.read().strip()
                os.remove(flag_path(key))
            except OSError:
                found = ""
            if found:
                bullets = "\n".join(f"- {line}" for line in found.splitlines())
                note = (
                    "[style-gate] Your previous reply broke these output rules:\n"
                    f"{bullets}\n"
                    "Follow them from this reply on. Do not apologise for or mention this note."
                )
        print(json.dumps({"additional_context": note} if note else {}))


if __name__ == "__main__":
    try:
        main()
    except Exception:
        pass

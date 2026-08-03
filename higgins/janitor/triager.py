"""higgins.janitor.triager — Inbox → vault routing worker.

Reads files from vault.inbox (and optionally Me/Inbox), calls Claude to classify
each one, auto-moves high-confidence results, stages low-confidence ones for review.
Uses stdlib urllib — no external dependencies.
"""

import json
import os
import re
import urllib.request
import urllib.error
from datetime import datetime, timezone
from pathlib import Path
from typing import TYPE_CHECKING, Optional

if TYPE_CHECKING:
    from higgins.config import HigginsConfig


_TRIAGE_PENDING_DIR = "_ops/triage-pending"
_TRIAGE_LOG         = "_ops/janitor-logs/triage-log.jsonl"


# ── Entry point ───────────────────────────────────────────────────────────────

def run(cfg: "HigginsConfig") -> dict:
    """Triage all files in vault.inbox. Returns result dict."""
    api_key = _get_api_key()
    if not api_key:
        return {
            "worker": "triager",
            "ran":    False,
            "reason": "OPENCODE_API_KEY not found in env or ~/.local-secrets",
        }

    inbox = cfg.vault.inbox
    if not inbox.exists():
        inbox.mkdir(parents=True, exist_ok=True)

    files = sorted(
        f for f in inbox.iterdir()
        if f.is_file() and not f.name.startswith(".")
    )

    if not files:
        return {
            "worker":      "triager",
            "ran":         True,
            "files_found": 0,
            "reason":      "inbox empty",
        }

    auto_moved = 0
    staged     = 0
    errors     = 0

    for f in files:
        try:
            result = _triage_file(cfg, f, api_key, vault="AI")
            if result["action"] == "moved":
                auto_moved += 1
            else:
                staged += 1
        except Exception as e:
            errors += 1
            _stage_file(cfg, f,
                reasoning=f"Exception during triage: {e}",
                confidence=0.0,
                proposed=None)

    return {
        "worker":      "triager",
        "ran":         True,
        "files_found": len(files),
        "auto_moved":  auto_moved,
        "staged":      staged,
        "errors":      errors,
    }


# ── Per-file triage ───────────────────────────────────────────────────────────

def _triage_file(
    cfg: "HigginsConfig",
    f: Path,
    api_key: str,
    vault: str = "AI",
) -> dict:
    content = f.read_text(errors="replace")
    clf     = _classify(cfg, f.name, content, api_key)

    confidence  = float(clf.get("confidence", 0.0))
    destination = str(clf.get("destination", "")).strip()
    reason      = str(clf.get("reason", ""))

    # Below threshold or unresolvable → stage
    if confidence < cfg.janitor.triage_confidence_threshold or not destination:
        _stage_file(cfg, f,
            reasoning=reason, confidence=confidence, proposed=destination)
        return {"action": "staged", "file": f.name, "confidence": confidence}

    dst = _resolve_destination(cfg, destination)
    if dst is None:
        _stage_file(cfg, f,
            reasoning=f"Cannot resolve: {destination}",
            confidence=confidence, proposed=destination)
        return {"action": "staged", "file": f.name, "confidence": confidence}

    # Destination already exists → stage to avoid overwrite
    if dst.exists():
        _stage_file(cfg, f,
            reasoning=f"Destination already exists: {dst.relative_to(cfg.vault.ai.parent)}",
            confidence=confidence, proposed=destination)
        return {"action": "staged", "file": f.name, "confidence": confidence}

    # Auto-move
    dst.parent.mkdir(parents=True, exist_ok=True)
    f.rename(dst)
    _log_move(cfg, f.name, dst, confidence, reason)

    return {
        "action":      "moved",
        "file":        f.name,
        "destination": str(dst),
        "confidence":  confidence,
    }


# ── AI classification ─────────────────────────────────────────────────────────

def _classify(
    cfg: "HigginsConfig",
    filename: str,
    content: str,
    api_key: str,
) -> dict:
    """Call Claude to classify the file. Returns parsed dict."""
    tiers_desc = "\n".join(
        f"  - AI:{tier}/ — {_tier_hint(tier)}"
        for tier in cfg.vault.tiers.as_dict()
    )

    prompt = f"""You are a vault archivist. Classify this inbox file for routing.

Vault destinations:
{tiers_desc}
  - Me:Personal/  — personal life, family, home, finances
  - Me:Work/      — professional work, clients, projects
  - Me:Ideas/     — ideas, concepts, future projects
  - Me:Plans/     — plans, active or done
  - Me:Development/ — tech notes, homelab

File name: {filename}
Content (first 1500 chars):
{content[:1500]}

Respond with ONLY valid JSON, no markdown fences:
{{
  "destination": "AI:personal/gotchas.md",
  "confidence": 0.90,
  "reason": "one sentence"
}}

Rules:
- destination prefix: "AI:" for agent knowledge, "Me:" for personal human notes
- AI:projects/<slug>/<file>.md for project-specific knowledge (infer slug)
- confidence 0.0-1.0; use < 0.80 when uncertain
- If truly unclear, set destination to "_ops/triage-pending" with confidence 0.3"""

    payload = json.dumps({
        "model":      cfg.janitor.ai_model,
        "max_tokens": 256,
        "messages":   [{"role": "user", "content": prompt}],
    }).encode()

    req = urllib.request.Request(
        "https://opencode.ai/zen/v1/responses",
        data=payload,
        headers={
            "Authorization":  f"Bearer {api_key}",
            "Content-Type":   "application/json",
        },
        method="POST",
    )

    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            body = json.loads(resp.read())
    except urllib.error.HTTPError as e:
        raise RuntimeError(
            f"OpenCode API {e.code}: {e.read().decode()[:200]}"
        )

    text = body["choices"][0]["message"]["content"].strip()
    text = re.sub(r"^```[a-z]*\n?", "", text)
    text = re.sub(r"\n?```$", "",  text)

    return json.loads(text)


# ── Destination resolution ────────────────────────────────────────────────────

def _resolve_destination(
    cfg: "HigginsConfig",
    destination: str,
) -> Optional[Path]:
    """Convert AI's destination string to an absolute Path. Returns None if unresolvable."""
    if not destination or destination.startswith("_ops/triage-pending"):
        return None

    if destination.startswith("AI:"):
        return cfg.vault.ai / destination[3:]
    if destination.startswith("Me:"):
        return cfg.vault.me / destination[3:]

    # Bare path: treat as AI-relative
    return cfg.vault.ai / destination


# ── Staging ───────────────────────────────────────────────────────────────────

def _stage_file(
    cfg: "HigginsConfig",
    f: Path,
    *,
    reasoning: str,
    confidence: float,
    proposed: Optional[str],
) -> None:
    """Move file to _ops/triage-pending/ and append AI reasoning."""
    pending = cfg.vault.ai / _TRIAGE_PENDING_DIR
    pending.mkdir(parents=True, exist_ok=True)

    content = f.read_text(errors="replace")
    ts      = datetime.now(timezone.utc).strftime("%Y-%m-%d")

    annotation = (
        f"\n\n---\n"
        f"<!-- higgins-triage: staged {ts} -->\n"
        f"<!-- confidence: {confidence:.2f} -->\n"
        f"<!-- proposed: {proposed or 'unknown'} -->\n"
        f"<!-- reason: {reasoning} -->\n"
    )

    dst = pending / f.name
    if dst.exists():
        dst = pending / f"{f.stem}-{ts}{f.suffix}"

    dst.write_text(content + annotation, encoding="utf-8")
    f.unlink()


# ── Logging ───────────────────────────────────────────────────────────────────

def _log_move(
    cfg: "HigginsConfig",
    src_name: str,
    dst: Path,
    confidence: float,
    reason: str,
) -> None:
    log_file = cfg.vault.ai / _TRIAGE_LOG
    record   = {
        "ts":         datetime.now(timezone.utc).isoformat(),
        "src":        src_name,
        "dst":        str(dst.relative_to(cfg.vault.ai)),
        "confidence": round(confidence, 3),
        "reason":     reason,
    }
    with open(log_file, "a", encoding="utf-8") as fh:
        fh.write(json.dumps(record) + "\n")


# ── Helpers ───────────────────────────────────────────────────────────────────

def _get_api_key():
    """Get AI API key from env, ~/.local-secrets, or Pi auth.json."""
    for var in ("OPENCODE_API_KEY", "ANTHROPIC_API_KEY"):
        key = os.environ.get(var)
        if key:
            return key

    secrets = Path.home() / ".local-secrets"
    if secrets.exists():
        for line in secrets.read_text().splitlines():
            line = line.strip()
            for var in ("OPENCODE_API_KEY", "ANTHROPIC_API_KEY"):
                if line.startswith(f"export {var}=") or line.startswith(f"{var}="):
                    val = line.split("=", 1)[1].strip().strip("'\"")
                    if val and not val.startswith("#"):
                        return val

    # Fallback: Pi opencode auth (macbro only)
    pi_auth = Path.home() / ".pi" / "agent" / "auth.json"
    if pi_auth.exists():
        try:
            import json as _j
            k = _j.loads(pi_auth.read_text()).get("opencode", {}).get("key")
            if k:
                return k
        except Exception:
            pass

    return None



def _tier_hint(tier: str) -> str:
    return {
        "personal": "cross-cutting facts, preferences, gotchas, decisions",
        "projects": "project-specific knowledge (use project slug as subfolder)",
        "modules":  "reusable technical patterns and knowledge units",
        "infra":    "machine/server state and configuration",
        "sessions": "session extracts — written by janitor only",
    }.get(tier, tier)


"""higgins.config — load and validate higgins.conf (TOML, stdlib-only)."""

import os
import sys
import tomllib
from dataclasses import dataclass, field
from pathlib import Path
from typing import Optional


_DEFAULT_CONFIG_PATH = Path("~/.config/higgins/higgins.conf")
_ENV_CONFIG_PATH = "HIGGINS_CONF"


def _expand(p: str) -> Path:
    return Path(p).expanduser().resolve()


# ── Config dataclasses ────────────────────────────────────────────────────────

@dataclass
class VaultTiers:
    personal: str = "personal"
    projects: str = "projects"
    modules:  str = "modules"
    infra:    str = "infra"
    sessions: str = "sessions"

    def as_dict(self) -> dict[str, str]:
        return {k: v for k, v in vars(self).items() if not k.startswith("_")}

    def path_for(self, tier: str, ai_root: Path) -> Path:
        folder = self.as_dict().get(tier)
        if folder is None:
            raise ValueError(f"Unknown tier '{tier}'. Known: {list(self.as_dict())}")
        return ai_root / folder


@dataclass
class VaultConfig:
    root:  Path
    ai:    Path
    me:    Path
    inbox: Path
    tiers: VaultTiers = field(default_factory=VaultTiers)


@dataclass
class IndexConfig:
    db:            Path
    meta:          Path
    max_write_lag: int = 20   # reindex after N vault writes
    max_age_hours: int = 72   # reindex if older than N hours regardless


@dataclass
class JanitorWorkers:
    indexer:  bool = True
    promoter: bool = True
    triager:  bool = True
    reviewer: bool = False   # quarterly — off by default


@dataclass
class JanitorConfig:
    enabled:                     bool = True
    log_dir:                     Optional[Path] = None  # defaults to vault.ai/_ops/janitor-logs
    ai_model:                    str = "claude-haiku-4-5"
    triage_confidence_threshold: float = 0.80
    workers: JanitorWorkers = field(default_factory=JanitorWorkers)


@dataclass
class MeReviewConfig:
    stale_months:         int   = 18
    similarity_threshold: float = 0.75


@dataclass
class HigginsConfig:
    vault:     VaultConfig
    index:     IndexConfig
    janitor:   JanitorConfig
    me_review: MeReviewConfig

    def tier_path(self, tier: str) -> Path:
        return self.vault.tiers.path_for(tier, self.vault.ai)


# ── Internal helpers ──────────────────────────────────────────────────────────

def _default_raw(vault_root: Path) -> dict:
    cache = Path("~/.cache/higgins").expanduser()
    return {
        "vault": {
            "root":  str(vault_root),
            "ai":    str(vault_root / "AI"),
            "me":    str(vault_root / "Me"),
            "inbox": str(vault_root / "Inbox"),
            "ai_tiers": {
                "personal": "personal",
                "projects": "projects",
                "modules":  "modules",
                "infra":    "infra",
                "sessions": "sessions",
            },
        },
        "index": {
            "db":            str(cache / "fts.db"),
            "meta":          str(cache / "meta.json"),
            "max_write_lag": 20,
            "max_age_hours": 72,
        },
        "janitor": {
            "enabled":                     True,
            "ai_model":                    "claude-haiku-4-5",
            "triage_confidence_threshold": 0.80,
            "workers": {
                "indexer":  True,
                "promoter": True,
                "triager":  True,
                "reviewer": False,
            },
        },
        "me_review": {
            "stale_months":         18,
            "similarity_threshold": 0.75,
        },
    }


def _parse(raw: dict) -> HigginsConfig:
    v    = raw.get("vault", {})
    root = _expand(v.get("root",  "~/Vaults/Higgins"))
    ai   = _expand(v.get("ai",   str(root / "AI")))
    me   = _expand(v.get("me",   str(root / "Me")))
    inbx = _expand(v.get("inbox", str(root / "Inbox")))

    t = v.get("ai_tiers", {})
    tiers = VaultTiers(
        personal = t.get("personal", "personal"),
        projects = t.get("projects", "projects"),
        modules  = t.get("modules",  "modules"),
        infra    = t.get("infra",    "infra"),
        sessions = t.get("sessions", "sessions"),
    )

    ix    = raw.get("index", {})
    cache = Path("~/.cache/higgins").expanduser()
    index = IndexConfig(
        db            = _expand(ix.get("db",   str(cache / "fts.db"))),
        meta          = _expand(ix.get("meta", str(cache / "meta.json"))),
        max_write_lag = int(ix.get("max_write_lag", 20)),
        max_age_hours = int(ix.get("max_age_hours", 72)),
    )

    j       = raw.get("janitor", {})
    jw      = j.get("workers", {})
    log_raw = j.get("log_dir")
    log_dir = _expand(log_raw) if log_raw else ai / "_ops" / "janitor-logs"

    janitor = JanitorConfig(
        enabled                     = bool(j.get("enabled", True)),
        log_dir                     = log_dir,
        ai_model                    = str(j.get("ai_model", "claude-haiku-4-5")),
        triage_confidence_threshold = float(j.get("triage_confidence_threshold", 0.80)),
        workers = JanitorWorkers(
            indexer  = bool(jw.get("indexer",  True)),
            promoter = bool(jw.get("promoter", True)),
            triager  = bool(jw.get("triager",  True)),
            reviewer = bool(jw.get("reviewer", False)),
        ),
    )

    mr = raw.get("me_review", {})
    me_review = MeReviewConfig(
        stale_months         = int(mr.get("stale_months", 18)),
        similarity_threshold = float(mr.get("similarity_threshold", 0.75)),
    )

    return HigginsConfig(
        vault     = VaultConfig(root=root, ai=ai, me=me, inbox=inbx, tiers=tiers),
        index     = index,
        janitor   = janitor,
        me_review = me_review,
    )


def _validate(cfg: HigginsConfig) -> list[str]:
    """Validate config. Raises on fatal errors, returns warnings list."""
    warnings = []

    if not cfg.vault.ai.exists():
        raise FileNotFoundError(
            f"vault.ai does not exist: {cfg.vault.ai}\n"
            "Run 'higgins init' to configure or set HIGGINS_CONF."
        )
    if not cfg.vault.me.exists():
        warnings.append(f"vault.me not found: {cfg.vault.me}")
    if not cfg.vault.inbox.exists():
        warnings.append(f"vault.inbox not found: {cfg.vault.inbox} (created on first triage)")

    # Cache + log dirs are machine-local — create silently
    cfg.index.db.parent.mkdir(parents=True, exist_ok=True)
    cfg.janitor.log_dir.mkdir(parents=True, exist_ok=True)

    return warnings


# ── Public API ────────────────────────────────────────────────────────────────

def config_path() -> Path:
    """Return the active config file path (from env or default)."""
    env = os.environ.get(_ENV_CONFIG_PATH)
    return Path(env).expanduser() if env else _DEFAULT_CONFIG_PATH.expanduser()


def load_config(
    path: Optional[Path] = None,
    *,
    validate: bool = True,
    warn: bool = True,
) -> HigginsConfig:
    """Load HigginsConfig from path, $HIGGINS_CONF, or ~/.config/higgins/higgins.conf.

    Falls back to built-in defaults when no config file exists, allowing
    'higgins init' and 'higgins status' to work before first-time setup.
    """
    if path is None:
        path = config_path()

    if not path.exists():
        return _parse(_default_raw(Path("~/Vaults/Higgins").expanduser()))

    with open(path, "rb") as f:
        raw = tomllib.load(f)

    cfg = _parse(raw)

    if validate:
        try:
            warnings = _validate(cfg)
        except FileNotFoundError as e:
            print(f"higgins: error: {e}", file=sys.stderr)
            sys.exit(1)
        if warn:
            for w in warnings:
                print(f"higgins: warning: {w}", file=sys.stderr)

    return cfg


def write_default_config(vault_root: Path, dest: Path) -> None:
    """Write a starter higgins.conf to dest. Creates parent dirs."""
    defaults = _default_raw(vault_root.resolve())
    dest.parent.mkdir(parents=True, exist_ok=True)

    v  = defaults["vault"]
    ix = defaults["index"]
    j  = defaults["janitor"]
    jw = j["workers"]
    mr = defaults["me_review"]

    bool_toml = lambda b: "true" if b else "false"

    lines = [
        "# higgins.conf — Higgins package configuration",
        "# Generated by 'higgins init'. Edit freely.",
        "",
        "[vault]",
        f'root   = "{v["root"]}"',
        f'ai     = "{v["ai"]}"',
        f'me     = "{v["me"]}"',
        f'inbox  = "{v["inbox"]}"',
        "",
        "[vault.ai_tiers]",
        *[f'{k:10} = "{fv}"' for k, fv in v["ai_tiers"].items()],
        "",
        "[index]",
        f'db            = "{ix["db"]}"',
        f'meta          = "{ix["meta"]}"',
        f'max_write_lag = {ix["max_write_lag"]}   # reindex after N vault writes',
        f'max_age_hours = {ix["max_age_hours"]}   # reindex if older than N hours',
        "",
        "[janitor]",
        f'enabled                     = {bool_toml(j["enabled"])}',
        f'ai_model                    = "{j["ai_model"]}"',
        f'triage_confidence_threshold = {j["triage_confidence_threshold"]}',
        "",
        "[janitor.workers]",
        f'indexer  = {bool_toml(jw["indexer"])}',
        f'promoter = {bool_toml(jw["promoter"])}',
        f'triager  = {bool_toml(jw["triager"])}',
        f'reviewer = {bool_toml(jw["reviewer"])}   # quarterly — enable manually',
        "",
        "[me_review]",
        f'stale_months         = {mr["stale_months"]}',
        f'similarity_threshold = {mr["similarity_threshold"]}',
        "",
    ]

    dest.write_text("\n".join(lines))

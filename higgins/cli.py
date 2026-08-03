"""higgins.cli — entry point for the higgins command (python3 -m higgins.cli)."""

import sys
from pathlib import Path


# ── Commands ──────────────────────────────────────────────────────────────────

def cmd_status(args: list[str]) -> None:
    from higgins.config import load_config, config_path

    path = config_path()
    exists = path.exists()

    if not exists:
        print(f"No config found at {path}")
        print("Run: higgins init")
        return

    cfg = load_config(path, validate=True, warn=False)

    def mark(p: Path) -> str:
        return "ok" if p.exists() else "MISSING"

    import json
    from higgins.index import meta_read  # noqa — imported lazily so status works pre-step2

    print(f"higgins {_version()}")
    print()
    print(f"Config:       {path}")
    print()
    print("Vault:")
    print(f"  ai:     {cfg.vault.ai}  [{mark(cfg.vault.ai)}]")
    print(f"  me:     {cfg.vault.me}  [{mark(cfg.vault.me)}]")
    print(f"  inbox:  {cfg.vault.inbox}  [{mark(cfg.vault.inbox)}]")
    print()
    print("Index:")
    print(f"  db:     {cfg.index.db}  [{mark(cfg.index.db)}]")
    try:
        meta = meta_read(cfg)
        print(f"  chunks: {meta.get('total_chunks', '?')}")
        print(f"  last indexed: {meta.get('last_indexed', 'never')}")
        print(f"  writes since index: {meta.get('writes_since_index', 0)}")
    except Exception:
        print("  meta: not available")
    print()
    print("Janitor:")
    w = cfg.janitor.workers
    print(f"  enabled:  {cfg.janitor.enabled}")
    print(f"  workers:  indexer={w.indexer}  promoter={w.promoter}  "
          f"triager={w.triager}  reviewer={w.reviewer}")
    print(f"  log_dir:  {cfg.janitor.log_dir}  [{mark(cfg.janitor.log_dir)}]")


def cmd_init(args: list[str]) -> None:
    from higgins.config import config_path, write_default_config, load_config

    force = "--force" in args
    dest  = config_path()

    if dest.exists() and not force:
        print(f"Config already exists: {dest}")
        print("Use --force to overwrite.")
        return

    # Vault root: from arg, or detect default
    non_flag = [a for a in args if not a.startswith("--")]
    if non_flag:
        vault_root = Path(non_flag[0]).expanduser().resolve()
    else:
        default = Path("~/Vaults/Higgins").expanduser()
        if default.exists():
            vault_root = default
        else:
            print("Cannot detect vault root. Provide it explicitly:")
            print("  higgins init ~/path/to/vault")
            sys.exit(1)

    write_default_config(vault_root, dest)
    print(f"Created: {dest}")
    print(f"Vault:   {vault_root}")

    cfg = load_config(dest, validate=False)

    # Create inbox if missing (safe to create)
    if not cfg.vault.inbox.exists():
        cfg.vault.inbox.mkdir(parents=True, exist_ok=True)
        print(f"Created: {cfg.vault.inbox}")

    print()
    print("Run 'higgins status' to verify.")


def cmd_search(args: list[str]) -> None:
    from higgins.config import load_config
    from higgins.index import search, search_format_text

    query_parts = [a for a in args if not a.startswith("--")]
    tier = next((a.split("=", 1)[1] for a in args if a.startswith("--tier=")), "")

    if not query_parts:
        print("usage: higgins search <query> [--tier=personal|projects|modules|infra]",
              file=sys.stderr)
        sys.exit(1)

    cfg     = load_config()
    results = search(cfg, " ".join(query_parts), tier=tier)
    print(search_format_text(results))


def cmd_reindex(args: list[str]) -> None:
    from higgins.config import load_config
    from higgins.index import reindex

    cfg = load_config()
    n   = reindex(cfg, verbose=True)
    print(f"Done: {n} chunks indexed.")


def cmd_version(args: list[str]) -> None:
    print(f"higgins {_version()}")


# ── Helpers ───────────────────────────────────────────────────────────────────

def _version() -> str:
    try:
        from higgins import __version__
        return __version__
    except Exception:
        return "unknown"


_HELP = """\
higgins — vault-aware knowledge package

Commands:
  init [vault_root]              create ~/.config/higgins/higgins.conf
  status                         show config + vault health + index state
  search <query> [--tier=TIER]   full-text search (FTS5, BM25 ranked)
  reindex                        rebuild FTS5 search index
  version                        print version

  janitor run                    run all enabled workers  [step 3+]
  janitor status                 last run + schedule      [step 3+]

Tiers: personal | projects | modules | infra | sessions

Options:
  -h, --help          show this help

Config: ~/.config/higgins/higgins.conf  (override: $HIGGINS_CONF)
"""


# ── Entry point ───────────────────────────────────────────────────────────────

def main() -> None:
    args = sys.argv[1:]

    if not args or args[0] in ("-h", "--help", "help"):
        print(_HELP)
        return

    cmd  = args[0]
    rest = args[1:]

    dispatch = {
        "init":    cmd_init,
        "status":  cmd_status,
        "search":  cmd_search,
        "reindex": cmd_reindex,
        "version": cmd_version,
    }

    handler = dispatch.get(cmd)
    if handler:
        handler(rest)
    else:
        print(f"higgins: unknown command '{cmd}'. Try: higgins help", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()

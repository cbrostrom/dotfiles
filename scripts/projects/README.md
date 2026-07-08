# Projects Cleanup Toolkit

Consolidate `~/Projects` into a client-first structure and generate a flat symlink farm for project navigation.

## Scripts

| Script | Purpose |
|---|---|
| `inventory.sh` | Scan all repos under `~/Projects`. Produces `_inventory.md` + `_inventory.json` + `plan.template.yml` |
| `apply.sh` | Execute approved moves from `plan.yml` with journal and rollback support |
| `sync-symlinks.sh` | Regenerate `~/.project-farm/` symlink farm |
| `lib.sh` | Shared helpers (sourced by the others) |

## Workflow

```
1. inventory.sh                       → generates report + plan template
2. cp plan.template.yml plan.yml      → copy and edit
3. (in Cursor with AI help)           → set approved: true per line
4. apply.sh --dry-run                 → preview
5. apply.sh --execute                 → run moves + sync symlinks
```

## Target structure

```
~/Projects/
├── clients/<client>/<repo>/
├── internal/<repo>/
├── personal/<repo>/
├── sandbox/<repo>/
├── _assets/    # loose files that are not code
└── _archive/   # old/duplicate repos
```

## Project farm

A flat symlink farm at `~/.project-farm/` exposes every repo to fuzzy finders and sessionizers.

```
~/.project-farm/<client>-<repo>  → ~/Projects/clients/<client>/<repo>
~/.project-farm/<repo>           → ~/Projects/personal/<repo>
```

## Safety

- `apply.sh` defaults to `--dry-run`
- Only moves with `approved: true` are executed
- All ops logged to `~/Projects/_journal/<timestamp>.log`
- Rollback: `apply.sh --rollback <journal-file>`

## Requirements

`fd`, `jq`, `git`, `bash 4+`. macOS ships bash 3.2 (scripts guard and re-exec via Homebrew bash).

---

## kb map

Registry + CODEBASE generator. Entry point: `kb map <subcommand>`.

| Script | Purpose |
|--------|---------|
| `map.sh` | Dispatcher — routes to map-*.sh |
| `map-scan.sh` | Read `_inventory.json` → write `$VAULT_AI/personal/projects-registry.md` |
| `map-codebase.sh` | Generate `CODEBASE.md` skeleton in repo root |
| `map-doctor.sh` | AI setup audit (read-only) |

**Config:** `~/dotfiles/config/projects-map.conf` — edit to add roots, repos, category rules.

```bash
kb map scan                    # build/refresh registry
kb map scan --refresh-inventory  # force inventory.sh re-run first
kb map list                    # read registry table (no rescan)
kb map codebase <path>         # generate CODEBASE.md
kb map doctor                  # AI bloat audit
```

Registry output: `~/Vaults/AI/personal/projects-registry.md`

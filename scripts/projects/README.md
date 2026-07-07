# Projects Cleanup Toolkit

Konsolidér `~/Projects` til klient-først struktur og generer en flad symlink-farm til zellij-sessionizer.

## Scripts

| Script | Formål |
|---|---|
| `inventory.sh` | Scan alle repos under `~/Projects`. Producerer `_inventory.md` + `_inventory.json` + `plan.template.yml` |
| `apply.sh` | Eksekver godkendte moves fra `plan.yml` med journal og rollback-support |
| `sync-symlinks.sh` | Regenerer `~/.zellij-projects/` symlink-farm |
| `lib.sh` | Shared helpers (sourced af de andre) |

## Workflow

```
1. inventory.sh                       → genererer rapport + plan-skabelon
2. cp plan.template.yml plan.yml      → kopier og rediger
3. (i Cursor med AI hjælp)            → sæt approved: true per linje
4. apply.sh --dry-run                 → preview
5. apply.sh --execute                 → kør moves + sync symlinks + opdater zellij
```

## Ny struktur (mål)

```
~/Projects/
├── clients/<klient>/<repo>/
├── internal/<repo>/
├── personal/<repo>/
├── sandbox/<repo>/
├── _assets/    # løse filer der ikke er kode
└── _archive/   # gamle/duplikat repos
```

## Symlink-farm

Sessionizer ser kun 1 niveau dybt. Derfor genereres:

```
~/.zellij-projects/<klient>-<repo>  → ~/Projects/clients/<klient>/<repo>
~/.zellij-projects/<repo>           → ~/Projects/personal/<repo>
```

Sessionizer config: `root_dirs "/Users/Christian.Brostrom/.zellij-projects"`

## Sikkerhed

- `apply.sh` defaulter til `--dry-run`
- Kun moves med `approved: true` udføres
- Alle ops logges til `~/Projects/_journal/<timestamp>.log`
- Rollback: `apply.sh --rollback <journal-file>`

## Krav

`fd`, `jq`, `git`, `bash 4+`. Macos bash 3.2 fungerer (scripts undgår 4+ features).

---

## kb map

Registry + CODEBASE generator. Entry point: `kb map <subcommand>`.

| Script | Purpose |
|--------|---------|
| `map.sh` | Dispatcher — routes to map-*.sh |
| `map-scan.sh` | Read `_inventory.json` → write `$VAULT_AI/personal/projects-registry.md` |
| `map-codebase.sh` _(P1)_ | Generate `CODEBASE.md` skeleton in repo root |
| `map-doctor.sh` _(P2)_ | AI setup audit (read-only) |

**Config:** `~/dotfiles/config/projects-map.conf` — edit to add roots, repos, category rules.

```bash
kb map scan                    # build/refresh registry
kb map scan --refresh-inventory  # force inventory.sh re-run first
kb map list                    # read registry table (no rescan)
kb map codebase <path>         # generate CODEBASE.md (P1)
kb map doctor                  # AI bloat audit (P2)
```

Registry output: `~/Vaults/AI/personal/projects-registry.md`

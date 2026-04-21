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

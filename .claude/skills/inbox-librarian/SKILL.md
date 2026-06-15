---
name: inbox-librarian
description: "Triage Inbox/ oldest-first. Confirm-per-file. Routes to vault per frontmatter contract. Never auto-routes, never edits body. Triggered by 'run librarian' / 'triage inbox' / 'process inbox'"
trigger: /inbox-librarian
group: vault
---

# Inbox Librarian

Process `$VAULT/Inbox/` oldest-first. Confirm each file. No silent moves.

## Setup

Detect vault:
- macOS (`uname` = Darwin): `VAULT=~/Vaults/Brain`
- WSL (`/proc/version` contains "microsoft"): `VAULT=/mnt/c/Users/christian/Obsidian/Brain`

List files: `find $VAULT/Inbox -maxdepth 1 -name "*.md" ! -name "_*" | sort` (oldest first via filename timestamp or mtime).

## Per-file loop

For each file:

### 1. Read

Read file. Extract:
- Inline hashtags (`#word`, `#area/project`)
- Filename tokens
- Body keywords

### 2. Infer

| Priority | Source | Extract |
|---|---|---|
| 1st | Inline `#personal #work #dev #idea #meta` | → `area` |
| 1st | Inline `#brain #ref #project #meeting #plan #note` | → `type` |
| 1st | Inline `#area/sub` (2-level max) | → area + project hint |
| 2nd | Filename tokens | infer if no hashtags |
| 3rd | Body keywords | fallback |
| Any other hashtag | → `tags[]` |

Hashtags stay in body — copy to frontmatter, don't strip.

### 3. Backlinks

Grep vault for entity names from file content:
`grep -rl "<entity>" $VAULT --include="*.md"` (1-3 terms max, pick salient nouns).
Propose `[[link]]` only if target file found. No fabricated links.

### 4. Destination

Per routing table:
| type | dest |
|---|---|
| brain | `$VAULT/Brains/<slug>.md` — APPEND dated section, don't replace |
| project | `$VAULT/<area-folder>/<project>/` |
| reference | `$VAULT/<area>/Reference/` or `$VAULT/Reference/` if cross-cutting |
| idea | `$VAULT/Ideas/<name>/` |
| note / meeting | `$VAULT/<area>/<context>/` |
| plan | `$VAULT/Plans/Active/YYYY-MM-DD-<topic>.md` |

### 5. Propose

Show compact proposal block:
```
━━ <filename> ━━
  area: <value>   type: <value>   tags: [<list>]
  dest: <path> (<MOVE or APPEND>)
  backlinks: [[<link1>]], [[<link2>]]
  [y]es / [n]o / [e]dit / [s]kip
```

Wait for input. Never proceed without explicit `y`.

### 6. Execute (on `y`)

1. Write frontmatter to file:
```yaml
---
created: <YYYY-MM-DD from filename or mtime>
area: <value>
type: <value>
tags: [<list>]
---
```
2. If backlinks: prepend `Cross-area: [[link]]` as first body line (after frontmatter).
3. If MOVE: move file to dest path (create dir if needed).
4. If APPEND (type=brain): append to existing `Brains/<slug>.md` as:
```md
## <YYYY-MM-DD> — <inferred topic>
<full file content>
```
   Then delete source file from Inbox.
5. Mention action in chat. No log file required.

### 7. Next file

Continue loop until all files processed or user says stop.

## Hard rules

- Never auto-route. Always show proposal + wait for confirm.
- Never edit body text — frontmatter + backlink prepend only.
- Never delete source file without moving/appending it first.
- No fabricated `[[links]]` — only targets confirmed to exist via grep.
- Brains APPEND, not replace.
- Inbox files with `_` prefix = skip (system files).

---
name: taskmaster
description: Vault-native project task state machine. Manages Projects/<slug>/tasks.md in ~/Vaults/Brain/. Read/write via native tools — no external parsers. Use when user invokes .task <cmd> or asks to manage project tasks across sessions.
trigger: .task
---

# taskmaster

Vault-native project task state machine. All state lives in `$VAULT/Projects/<slug>/tasks.md`. Claude is the runtime. Vault is the database. Obsidian is the UI.

## Vault Path

| Platform | Path |
|---|---|
| macOS | `~/Vaults/Brain` |
| WSL | `/mnt/c/Users/christian/Obsidian/Christian` |

Detect: `uname` = Darwin → macOS. Use `$VAULT` as shorthand.

## Tasks File Format

`$VAULT/Projects/<slug>/tasks.md`:

```markdown
---
project: <slug>
created: YYYY-MM-DD
---

## task-slug
- status: pending
- deps: []
- priority: high
- notes: Free text, supports [[wikilinks]]

## another-task
- status: done
- deps: [task-slug]
- priority: medium
- notes:
```

**Status values:** `pending` / `in-progress` / `done` / `blocked`
**IDs:** kebab-case slugs — human-readable, dep refs self-documenting
**Deps:** `[slug-a, slug-b]` — empty `[]` = no deps
**Notes:** free text, supports Obsidian `[[wikilinks]]` to brain notes

## Parse Rules

- Tasks = `## <slug>` headers in the file
- Fields = `- key: value` lines under each header, up to the next `##` or EOF
- Deps parsed: strip `[` `]`, split on `,`, trim whitespace per element
- **Read:** native `Read` tool only — never shell cat/awk/sed
- **Write:** native `Write` tool — always full file rewrite (Read → modify in memory → Write)

## Slug Resolution

1. Explicit arg to `.task` command
2. `basename $PWD` (git repo name)
3. If ambiguous: ask via `AskUserQuestion`

If `tasks.md` not found → tell user to run `.task init [slug]`.

---

## Subcommands

### `.task help`

Print this table:

```
.task init [slug]                  — create Projects/<slug>/tasks.md
.task add <slug> [deps:a,b] [priority:high|medium|low]
.task next                         — first unblocked pending task
.task done <slug>                  — mark done, show newly unblocked
.task block <slug> [reason]        — mark blocked with reason
.task expand <slug>                — AI decompose into subtasks
.task status                       — full board grouped by status
```

---

### `.task init [slug]`

Slug defaults to `basename $PWD`.

1. Read `$VAULT/Projects/<slug>/tasks.md` — if exists, abort with message "tasks.md already exists at <path>"
2. Write `$VAULT/Projects/<slug>/tasks.md`:

```markdown
---
project: <slug>
created: <today>
---
```

3. If `$VAULT/Development/taskmaster.md` does not exist, create it:

```markdown
---
created: <today>
type: reference
tags: [taskmaster, projects]
---

# Taskmaster

Vault-native task state. Each project has `Projects/<slug>/tasks.md`.

Dataview board:
\`\`\`dataview
TABLE status, deps, priority FROM "Projects" WHERE contains(file.name, "tasks")
\`\`\`
```

4. Report: "Created `$VAULT/Projects/<slug>/tasks.md`"

---

### `.task add <slug> [deps:a,b] [priority:high|medium|low]`

Parse args:
- First positional arg = task slug (kebab-case)
- `deps:a,b` → split on `,` → dep list; default `[]`
- `priority:high|medium|low` → default `medium`

Read tasks.md → append new section → Write:

```markdown

## <slug>
- status: pending
- deps: [<deps>]
- priority: <priority>
- notes:
```

Report: "Added `<slug>` (priority: <priority>, deps: <deps>)"

---

### `.task next`

Algorithm:
1. Read tasks.md
2. Build done-set: all slugs where `status: done`
3. Filter: `status: pending` AND every element of deps in done-set (empty deps = always unblocked)
4. Sort: `high` → `medium` → `low`
5. Return top result

Output:
```
Next: <slug> [<priority>]
Notes: <notes if any>
```

If none unblocked: "No unblocked pending tasks."

---

### `.task done <slug>`

1. Read tasks.md
2. Set `status: done` for `<slug>`
3. Compute newly-unblocked: tasks where `status: pending` AND all deps now in done-set (treating `<slug>` as done)
4. Write updated file
5. Report:

```
✓ <slug> marked done
Unblocked: <slug-a>, <slug-b>   ← omit line if none
```

---

### `.task block <slug> [reason]`

1. Read tasks.md
2. Set `status: blocked` for `<slug>`
3. If reason given: append reason to notes field (prefix: `BLOCKED: `)
4. Write updated file
5. Report: "Blocked `<slug>`" + reason if given

---

### `.task expand <slug>`

1. Read slug's name + notes from tasks.md
2. Generate 3–6 concrete subtasks based on task name + notes (keep them actionable, kebab-named)
3. Append under the task's notes field as:

```
  - [ ] subtask-one
  - [ ] subtask-two
  - [ ] subtask-three
```

4. Write updated file
5. Report: "Expanded `<slug>` → N subtasks"

---

### `.task status`

Read tasks.md. Build done-set. Compute unblocked set (same logic as `.task next`).

Output grouped board:

```
**in-progress**
  - <slug> [deps: <deps>] [<priority>]

**pending — unblocked**
  - <slug> [deps: <deps>] [<priority>]

**pending — blocked**
  - <slug> [waiting on: <unfinished-deps>] [<priority>]

**done**
  - <slug>
```

Omit empty sections. For blocked tasks, show only the unfinished deps.

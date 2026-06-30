---
name: codebase
description: Codebase router. Reads CODEBASE.md and maps the current task to the 2-3 files worth reading next — prevents redundant searches. Offers to generate CODEBASE.md if missing. Triggered by 'codebase', 'where is X', 'what files do I need', 'map this repo', 'orient me'.
group: productivity
---

# Codebase Router

Reads the repo map and routes the agent to the right files for the current task.

## Workflow

### 1. Locate CODEBASE.md

```bash
ls CODEBASE.md 2>/dev/null || echo "MISSING"
```

**If missing → go to step 4.**

### 2. Read the map

Read `CODEBASE.md` in the current working directory.

### 3. Route

Based on the current task, output exactly:

```
## Codebase route

Task: <one-line task summary>

Read next:
- `<file or dir>` — <why>
- `<file or dir>` — <why>
- `<file or dir>` — <why> (optional third)

Skip: everything else.
```

Maximum 3 entries. No padding. If the task is clear and only 1–2 files are relevant, list only those.

---

### 4. Generate CODEBASE.md (only if missing)

Ask the user: "No CODEBASE.md found. Generate one? (takes ~5 seconds)"

If yes:

```bash
find . -maxdepth 2 \
  -not -path '*/\.*' \
  -not -path '*/node_modules/*' \
  -not -name '*.zwc' \
  -not -name '*.lock' \
  | sort
```

Use the output to write a `CODEBASE.md` in this format:

```markdown
# Codebase map — <repo name>

Read this before searching. Jump directly to the right file.

## Root

| File | Purpose |
|------|---------|
| `<file>` | <one-line purpose> |

## Key directories

### `<dir>/`
<one-line summary>

| File/subdir | Purpose |
|-------------|---------|
| `<entry>` | <one-line purpose> |
```

Rules for generation:
- Infer purpose from filenames and directory names only — do not read file contents
- One line per entry, no speculation
- Skip compiled/generated files (`.zwc`, `dist/`, `build/`, lockfiles)
- Skip dot-dirs unless they contain meaningful config (`.claude/`, `.cursor/` yes — `.git/` no)

After writing, run the router from step 2.

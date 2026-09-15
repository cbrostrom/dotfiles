---
name: codebase
description: "Maps the current task to 2-3 files to read. Reads CODEBASE.md; generates it if missing. Triggers: codebase, where is X, what files do I need, map this repo, orient me."
group: productivity
---

# Codebase Router

Reads the repo map and routes the agent to the right files for the current task.

## Fast path — deterministic orient (preferred when available)

If `~/dotfiles/scripts/projects/repo-orient.py` exists, route mechanically first:

```bash
python3 ~/dotfiles/scripts/projects/repo-orient.py orient "<task>" [--graph]
```

- Returns ≤3 verified paths with reasons, commands, and a skip list — same contract as step 4.
- Add `--graph` only when codebase-memory is useful; failure falls back cleanly.
- Output is bounded (~800 tokens); paths are existence-checked; no file bodies are read.

If the command succeeds, present its routes in the step-4 format and stop.
Fall back to the manual workflow below if the script is missing or errors.

## Workflow

### 1. Locate CODEBASE.md

```bash
ls CODEBASE.md 2>/dev/null || echo "MISSING"
```

**If missing → go to step 4.**

### 2. Read the map

Read `CODEBASE.md` in the current working directory.

### 3. Safety net — staleness check

Before routing, verify each entry you intend to route to still exists (`ls <path>`). If an entry is missing, or the map's file list looks wrong for the current tree:

1. Regenerate the map from scratch (step 4, overwriting the existing CODEBASE.md).
2. Re-run the router from step 2.

Never route to a nonexistent file — flag the stale entry to the user instead.

### 4. Route

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

### 5. Generate CODEBASE.md (only if missing or just invalidated by the safety net)

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
- Skip dot-dirs unless they contain meaningful config (`.cursor/`, `.config/pi/` yes — `.git/` no)

After writing, run the router from step 2.

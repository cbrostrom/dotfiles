---
name: dot-doctor
description: Dotfiles health check specialist. Runs doctor.sh and claude-settings doctor, interprets output intelligently — distinguishes real issues from expected warnings, proposes fix commands. Triggered by 'dot-doctor', 'dotfiles health', 'check setup', 'is my setup broken'.
group: dotfiles
---

# Dot Doctor

Runs the dotfiles health checks and tells you what actually matters.

## Workflow

### 1. Run checks
```bash
cd ~/dotfiles
bash scripts/doctor.sh 2>&1
bash modules/claude-settings/doctor.sh 2>&1
```

### 2. Classify output

| Signal | Class | Action |
|---|---|---|
| `[OK]` / `ok` | Healthy | Ignore |
| `[WARN]` about shellcheck SC208x | Cosmetic | Mention once, don't list each one |
| `[WARN]` about missing optional tool | Cosmetic | Ignore unless user asks |
| `[BAD]` / `bad` | Real issue | Surface with fix command |
| `[WARN]` about broken symlink | Real issue | Surface with fix command |
| `[WARN]` about settings drift | Real issue | Surface with `doctor --fix` |
| Missing hook that IS wired in settings | Real issue | Surface |
| Missing hook that is NOT wired | Cosmetic | Skip |

### 3. Report format

```
## Dotfiles Health

✓ All good — [N] checks passed

OR

⚠ Issues found:

**[Issue description]**
Fix: `[exact command]`

**[Issue description]**
Fix: `[exact command]`

[N] cosmetic warnings suppressed (shellcheck style, optional tools).
Run `bash scripts/doctor.sh` for full output.
```

### 4. Auto-fix (only on explicit "fix it" / "run the fix")
```bash
bash modules/claude-settings/doctor.sh --fix
```
Never auto-fix symlinks without confirmation.

## Context knowledge
- SC2088 tilde-in-quotes warnings in `doctor.sh` are pre-existing, non-blocking — always suppress
- Single-item loop SC2043 in `doctor.sh` is pre-existing — suppress
- `settings.local.json` drift is expected after pulling on a new host — `doctor --fix` resolves it
- Missing `~/.claude/settings.override.json` is expected (per-host, gitignored)

# KB Evolution Plan — Haiku Implementation Spec
> Status: READY FOR IMPLEMENTATION
> Target model: Haiku (claude-haiku-4-5 or similar)
> Sonnet-designed, Haiku executes
> Monthly refresh cycle (not quarterly)

---

## CONTEXT

Vault: `~/Vaults/Higgins/AI/`
Dotfiles: `~/dotfiles/`
Scripts live in: `~/dotfiles/scripts/`
Janitor script: `~/dotfiles/scripts/janitor.sh`
Janitor config: `~/dotfiles/scripts/janitor.conf`

The vault has two key personal files:
- `~/Vaults/Higgins/AI/personal/gotchas.md` — traps and lessons
- `~/Vaults/Higgins/AI/personal/decisions.md` — architectural decisions

**Problem being solved:** These files accumulate without lifecycle. Gotchas stay listed even when resolved. Decisions are never validated. No feedback loop. This plan adds timestamps, status, and a monthly review workflow.

---

## WHAT TO BUILD

1. New format specs for `gotchas.md` and `decisions.md`
2. `kb-review.sh` — scanner that flags stale entries
3. `kb-refresh.sh` — monthly workflow runner (interactive)
4. Janitor integration — add `kb_health` section to health JSON report

**DO NOT:**
- Rewrite existing gotchas.md or decisions.md content (human does manual cleanup first)
- Modify the `kb` CLI binary at `~/dotfiles/scripts/kb`
- Touch `~/Vaults/Higgins/AI/personal/history/`
- Auto-archive anything (human reviews first, always)
- Add dependencies beyond bash + standard unix tools

---

## 1. FORMAT SPEC: gotchas.md

### Template for each entry:
```markdown
## [G-NNN] Short title
- Added: YYYY-MM-DD
- Status: ACTIVE
- Renewed: YYYY-MM-DD
- Trap: One sentence describing the trap
- Fix: One sentence describing the fix or workaround
```

### Status vocabulary (exactly 3 values):
- `ACTIVE` — still relevant, watch out
- `WATCH` — probably fixed but unconfirmed
- `RESOLVED` — confirmed fixed (keep 90 days, then archive)

### Resolution entry (append when resolving):
```markdown
## [G-NNN] Short title
- Added: YYYY-MM-DD
- Status: RESOLVED
- Renewed: YYYY-MM-DD
- Resolved: YYYY-MM-DD
- Trap: One sentence
- Fix: One sentence
- Resolution note: What confirmed it is fixed
```

### Staleness rule:
- If `Renewed` date is >30 days ago → flag in kb-review output
- If `Status: RESOLVED` and `Resolved` date is >90 days ago → candidate for history archive

### Example complete entry:
```markdown
## [G-001] pfctl rule order resets on macOS update
- Added: 2026-06-01
- Status: ACTIVE
- Renewed: 2026-07-28
- Trap: rdr-anchor must precede anchor in /etc/pf.conf — macOS updates silently reset
- Fix: sudo scripts/system/pf-caddy.sh after any macOS update
```

---

## 2. FORMAT SPEC: decisions.md

### Template for each entry:
```markdown
## [D-NNN] Short decision title
- Decided: YYYY-MM-DD
- Status: PENDING
- Hypothesis: Why we think this is the right call
- Success criteria: Measurable outcome that confirms it worked
- Validate by: YYYY-MM-DD
- Outcome: —
```

### Status vocabulary (exactly 4 values):
- `PENDING` — decided, not yet validated
- `VALIDATED` — hypothesis confirmed, outcome written
- `REVERSED` — was wrong, reverted (keep as lesson, never delete)
- `SUPERSEDED` — replaced by newer decision (add "Superseded by: [D-NNN]")

### Validation entry (append when validating):
```markdown
## [D-NNN] Short decision title
- Decided: YYYY-MM-DD
- Status: VALIDATED
- Hypothesis: Why we thought this was right
- Success criteria: Measurable outcome
- Validate by: YYYY-MM-DD
- Validated: YYYY-MM-DD
- Outcome: What actually happened, one paragraph max
```

### Ongoing decisions (no expiry):
- Use `Validate by: ONGOING` for permanent architectural choices
- janitor and kb-review skip these

### Example complete entry:
```markdown
## [D-001] Syncthing over rsync for vault sync
- Decided: 2026-07-28
- Status: PENDING
- Hypothesis: Reduces conflict resolution from manual to automatic, works across Linux/macOS
- Success criteria: <10 conflicts/month, zero data loss after 60 days
- Validate by: 2026-09-28
- Outcome: —
```

---

## 3. kb-review.sh

### Location: `~/dotfiles/scripts/kb-review.sh`
### Purpose: Scan gotchas.md and decisions.md, report stale entries

### Behaviour:
- Reads `VAULT_AI` from environment (default: `~/Vaults/Higgins/AI`)
- Scans `$VAULT_AI/personal/gotchas.md`
- Scans `$VAULT_AI/personal/decisions.md`
- Outputs a human-readable report to stdout
- Exit code 0 always (report only, no mutations)

### Staleness thresholds:
- Gotcha `Renewed` > 30 days ago → flag as STALE
- Decision `Validate by` date is in the past AND status is PENDING → flag as OVERDUE
- Decision `Validate by: ONGOING` → skip

### Output format (stdout):
```
=== KB Review — YYYY-MM-DD ===

GOTCHAS: 12 total | 9 active | 2 watch | 1 resolved
  STALE (not renewed >30 days):
    [G-003] pm2 after node upgrade — last renewed: 2026-05-01 (88 days ago)
    [G-007] git worktree prune — last renewed: 2026-04-15 (103 days ago)
  RESOLVED candidates (>90 days, archive these):
    [G-001] pfctl rule order — resolved: 2026-04-20 (98 days ago)

DECISIONS: 8 total | 3 pending | 4 validated | 1 reversed
  OVERDUE VALIDATION:
    [D-002] Janitor mechanical-first — validate by: 2026-08-28 (3 days overdue)
    [D-005] Bun over Node for scripts — validate by: 2026-07-01 (27 days overdue)

ACTION NEEDED: 4 items require review
```

### Implementation notes:
- Parse `Renewed: YYYY-MM-DD` lines with grep/awk/sed — no external parsers
- Parse `Validate by: YYYY-MM-DD` lines same way
- Cross-platform date math: use same pattern as janitor.sh (already has macOS/Linux compat)
- If a file doesn't exist, print warning and skip (don't fail)
- If no stale entries found, print "All entries current — no action needed"

---

## 4. kb-refresh.sh

### Location: `~/dotfiles/scripts/kb-refresh.sh`
### Purpose: Interactive monthly refresh workflow

### Behaviour:
- Runs `kb-review.sh` first, shows output
- Prints step-by-step instructions for human review
- Opens files in $EDITOR at the end (if set)
- Does NOT auto-modify any vault files
- Logs run to `$VAULT_AI/_ops/janitor-logs/kb-refresh-YYYY-MM-DD.log`

### Script flow:
```
1. Print header: "=== Monthly KB Refresh — YYYY-MM-DD ==="
2. Run kb-review.sh, show output
3. If no items flagged: print "Nothing stale. Run kb digest for session review." and exit 0
4. Print checklist:

   REVIEW CHECKLIST:
   [ ] For each STALE gotcha:
       → Open gotchas.md
       → If still relevant: update "Renewed: YYYY-MM-DD"
       → If resolved: change Status to RESOLVED, add "Resolved: YYYY-MM-DD"
       → If obsolete: change Status to RESOLVED with note "obsolete"

   [ ] For each OVERDUE decision:
       → Open decisions.md
       → Write outcome: what happened, was hypothesis correct?
       → Change Status to VALIDATED, REVERSED, or SUPERSEDED
       → Add "Validated: YYYY-MM-DD" line

   [ ] Run: kb digest
       → Accept/reject proposed updates from recent sessions

   [ ] Run: kb compact
       → Trims current.md to ≤5 bullets, moves overflow to history/

5. Print: "Open vault files now? [y/N]"
6. If y: open $VAULT_AI/personal/gotchas.md and decisions.md in $EDITOR
7. Print: "Refresh complete. Log saved to: [path]"
```

### Edge cases:
- If `$EDITOR` not set, print file paths instead of opening
- If `kb` binary not found at `~/dotfiles/scripts/kb`, skip kb digest/compact steps with warning
- Log all output to the log file (use `tee`)

---

## 5. JANITOR INTEGRATION

### Add `kb_health` to health report JSON

### Location in janitor.sh:
Find the section `# 6. HEALTH REPORT (JSON snapshot)` around line 225.
The current health JSON looks like:
```json
{
  "date": "...",
  "vault_size": "...",
  "projects": { ... },
  "archive": { ... },
  "logs": { ... },
  "ai": { ... }
}
```

### Add a new section BEFORE the closing `}` of the JSON:

```json
"kb_health": {
  "gotchas": {
    "total": 0,
    "active": 0,
    "watch": 0,
    "resolved": 0,
    "stale_renewal": 0,
    "stale_ids": []
  },
  "decisions": {
    "total": 0,
    "pending": 0,
    "validated": 0,
    "overdue_validation": 0,
    "overdue_ids": []
  },
  "last_refresh": "unknown",
  "next_refresh": "unknown"
}
```

### Implementation: add a parse step BEFORE the JSON is written

Add a new section `# 5b. KB HEALTH SCAN` between archive-cleanup and health-report:

```bash
# ============================================================================
# 5b. KB HEALTH SCAN
# ============================================================================
log "--- kb-health-scan ---"

GOTCHAS_FILE="$VAULT_AI/personal/gotchas.md"
DECISIONS_FILE="$VAULT_AI/personal/decisions.md"

# Initialize counters
KB_G_TOTAL=0; KB_G_ACTIVE=0; KB_G_WATCH=0; KB_G_RESOLVED=0; KB_G_STALE=0
KB_G_STALE_IDS=""
KB_D_TOTAL=0; KB_D_PENDING=0; KB_D_VALIDATED=0; KB_D_OVERDUE=0
KB_D_OVERDUE_IDS=""
KB_LAST_REFRESH="unknown"

# Parse gotchas.md
if [ -f "$GOTCHAS_FILE" ]; then
  # Count by status
  KB_G_TOTAL=$(grep -c "^## \[G-" "$GOTCHAS_FILE" 2>/dev/null || echo 0)
  KB_G_ACTIVE=$(grep -c "^- Status: ACTIVE" "$GOTCHAS_FILE" 2>/dev/null || echo 0)
  KB_G_WATCH=$(grep -c "^- Status: WATCH" "$GOTCHAS_FILE" 2>/dev/null || echo 0)
  KB_G_RESOLVED=$(grep -c "^- Status: RESOLVED" "$GOTCHAS_FILE" 2>/dev/null || echo 0)

  # Find stale renewals (Renewed > 30 days ago)
  # [Haiku: implement date comparison using same pattern as mechanical-pass-1]
  # For each "Renewed: YYYY-MM-DD" line, parse date, compare to today
  # If > 30 days: extract the [G-NNN] id from the preceding ## header
  # Append to KB_G_STALE_IDS, increment KB_G_STALE

fi

# Parse decisions.md
if [ -f "$DECISIONS_FILE" ]; then
  KB_D_TOTAL=$(grep -c "^## \[D-" "$DECISIONS_FILE" 2>/dev/null || echo 0)
  KB_D_PENDING=$(grep -c "^- Status: PENDING" "$DECISIONS_FILE" 2>/dev/null || echo 0)
  KB_D_VALIDATED=$(grep -c "^- Status: VALIDATED" "$DECISIONS_FILE" 2>/dev/null || echo 0)

  # Find overdue validations
  # For each "Validate by: YYYY-MM-DD" line (not ONGOING)
  # If date is in the past AND status is PENDING: flag
  # Append to KB_D_OVERDUE_IDS, increment KB_D_OVERDUE
fi

# Find last refresh log
LAST_REFRESH_LOG=$(ls "$LOG_DIR"/kb-refresh-*.log 2>/dev/null | sort | tail -1)
if [ -n "$LAST_REFRESH_LOG" ]; then
  KB_LAST_REFRESH=$(basename "$LAST_REFRESH_LOG" .log | sed 's/kb-refresh-//')
fi

# Calculate next refresh (last refresh + 30 days)
# [Haiku: implement cross-platform date math, same pattern as archive-cleanup]

log "kb-health: gotchas=$KB_G_TOTAL (stale=$KB_G_STALE) decisions=$KB_D_TOTAL (overdue=$KB_D_OVERDUE)"
```

### Add kb_health to the JSON (inside the heredoc):
```json
"kb_health": {
  "gotchas": {
    "total": $KB_G_TOTAL,
    "active": $KB_G_ACTIVE,
    "watch": $KB_G_WATCH,
    "resolved": $KB_G_RESOLVED,
    "stale_renewal": $KB_G_STALE,
    "stale_ids": "$KB_G_STALE_IDS"
  },
  "decisions": {
    "total": $KB_D_TOTAL,
    "pending": $KB_D_PENDING,
    "validated": $KB_D_VALIDATED,
    "overdue_validation": $KB_D_OVERDUE,
    "overdue_ids": "$KB_D_OVERDUE_IDS"
  },
  "last_refresh": "$KB_LAST_REFRESH",
  "next_refresh": "$KB_NEXT_REFRESH"
}
```

---

## 6. MONTHLY CRON

### Add to crontab on SuperBro (runs on the 1st of each month):
```
0 9 1 * * cd ~/dotfiles && source ~/.local-secrets && bash scripts/kb-refresh.sh >> ~/Vaults/Higgins/AI/_ops/janitor-logs/kb-refresh-$(date +\%Y-\%m-\%d).log 2>&1
```

**Note:** This logs the report but does NOT auto-modify files. Human still reviews and edits manually. The cron run just surfaces what needs attention.

---

## 7. COMMIT CONVENTION

All files go to `~/dotfiles/`. Commit in one batch:
```
feat(kb): add monthly refresh workflow and evolution lifecycle

- Add kb-review.sh: staleness scanner for gotchas + decisions
- Add kb-refresh.sh: interactive monthly refresh runner
- Add janitor kb_health section to health JSON
- Document gotchas/decisions format spec in docs/kb-evolution-plan.md
```

---

## 8. TESTING CHECKLIST

After implementation, verify:
```
[ ] kb-review.sh runs without error on current (unformatted) files
[ ] kb-review.sh correctly handles missing files (warn, no crash)
[ ] kb-review.sh correctly parses new-format entries (test with sample file)
[ ] kb-refresh.sh runs without error, prints checklist
[ ] kb-refresh.sh logs to correct location
[ ] janitor.sh runs cleanly with kb_health section added
[ ] janitor health JSON is valid JSON (test with: python3 -m json.tool health-*.json)
[ ] kb-review.sh date math works on both macOS and Linux
[ ] All scripts handle empty/missing vault gracefully
```

---

## 9. FILE PATHS SUMMARY

| File | Path |
|------|------|
| kb-review.sh | `~/dotfiles/scripts/kb-review.sh` |
| kb-refresh.sh | `~/dotfiles/scripts/kb-refresh.sh` |
| janitor.sh (modified) | `~/dotfiles/scripts/janitor.sh` |
| This plan | `~/dotfiles/docs/kb-evolution-plan.md` |
| gotchas.md (human cleans) | `~/Vaults/Higgins/AI/personal/gotchas.md` |
| decisions.md (human cleans) | `~/Vaults/Higgins/AI/personal/decisions.md` |
| Refresh logs | `~/Vaults/Higgins/AI/_ops/janitor-logs/kb-refresh-YYYY-MM-DD.log` |

---

## CRITICAL CONSTRAINTS FOR HAIKU

1. **Never auto-modify vault files** — scripts are read-only reporters
2. **No external dependencies** — bash + grep + awk + sed + date only
3. **Cross-platform date math** — test macOS (date -v) AND Linux (date -d) paths
4. **Append-only awareness** — do not suggest overwriting files, only appending
5. **Graceful degradation** — if vault path doesn't exist, warn and continue
6. **Valid JSON** — janitor health output must pass `python3 -m json.tool`
7. **Commit to dotfiles** — not to vault

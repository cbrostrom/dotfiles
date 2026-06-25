---
name: morning-brief
description: Daily morning context loader. Combines brain next.md priorities, today's calendar events, and open PRs into a compact brief (≤200 words). Triggered by 'morning brief', 'start day', 'what's on today', 'brief me'.
group: productivity
---

# Morning Brief

One-shot session starter. Loads everything you need to orient for the day without reading multiple tools.

## Sources

### 1. Brain context
```bash
brain load  # current state + pending next items
```
Show only top 3 `next.md` items (non-done, highest priority first).

### 2. Calendar (Google Calendar MCP, if available)
- Fetch today's events only
- Fields: time, title, attendee count
- Skip: all-day placeholder events, declined events

### 3. Open PRs (GitHub MCP, if available)
```
search: is:pr is:open author:@me
```
Show: repo, title, review status — max 3 PRs

### 4. Jira due/urgent (Atlassian MCP, if available)
- Issues assigned to me due today or overdue
- Max 2 items — just key + summary

## Output format

```
## Morning Brief — [weekday, date]

**Focus today:** [top 1-2 brain next items]

**Meetings:** [time — title (N people)] or "No meetings today"

**PRs needing attention:** [repo#N: title] or "None"

**Jira:** [KEY-N: title] or skipped if no urgent items

**Carry-forward:** [any brain gotcha or open decision worth flagging]
```

## Rules
- ≤200 words total
- No preamble, no "here is your brief"
- If a source is unavailable, skip its section silently
- Tone: direct, like a colleague handing you a note
- Run once at session start — don't re-run mid-session

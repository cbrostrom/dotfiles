---
name: standup
description: Daily standup generator. Pulls last 24h of git commits, in-progress Jira issues, and brain next.md done items → formats a tight 3-bullet standup (did / doing / blocked). Triggered by 'standup', 'daily', 'what did I do yesterday', 'generate standup'.
group: productivity
---

# Standup Generator

Generates a concise daily standup from real sources. No filler. Output ≤120 words.

## Sources

### 1. Git commits (last 24h)
```bash
git log --since="24 hours ago" --all --oneline --no-merges 2>/dev/null
```
Run in cwd and any sibling project dirs if visible. Summarise by project, not by commit.

### 2. Jira in-progress (if Atlassian MCP available)
- Fetch issues assigned to me with status "In Progress" or "In Review"
- Route: fiskars MCP if project context is Fiskars/AKQA, else developer MCP
- Pull: issue key, summary, status only — no full description

### 3. Brain next.md (done items from yesterday)
```bash
grep '\[done:' ~/Vaults/Brain/Brains/$(basename $(git rev-parse --show-toplevel 2>/dev/null || echo $PWD))/next.md 2>/dev/null | grep "$(date -v-1d '+%Y-%m-%d' 2>/dev/null || date -d 'yesterday' '+%Y-%m-%d' 2>/dev/null)"
```

## Output format

```
**Yesterday:** [1-3 things completed, summarised from commits + done items]
**Today:** [top 1-2 in-progress Jira items + next brain items]
**Blocked:** [anything blocking, or "Nothing blocking"]
```

Rules:
- Use plain language, no ticket-speak
- Merge git + Jira naturally — don't list both separately
- If no Jira access: derive "today" from brain `next.md` pending items
- If nothing found for a bullet: write one honest sentence
- Never pad with summaries of what standup is

## Token rules
- Never load full git diffs — `--oneline` only
- Never load full Jira issue body — summary + status only
- Cap at 3 Jira issues max

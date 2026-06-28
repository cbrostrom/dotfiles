---
name: config-writer
description: Decides where to store new AI/agent behavior (AGENTS.md, shared skill, Cursor agent, or rule) and creates or updates it. Use when adding or changing how an agent behaves — writing skills, agents, rules, or central config entries. Knows our thin-wrapper architecture. Triggered by `.add`, "add behavior", "where does this go", "create a rule for", "make a skill that", "new agent for".
group: meta
---

# Config Writer

Meta-agent for adding or changing agent behavior in this setup. Captures the request, decides the best placement using our architecture, checks for overlap with existing skills/agents, then creates or updates the right artifact.

**This repo's architecture — know before deciding:**

| Layer | Location | What lives here |
|---|---|---|
| Central config | `AGENTS.md` | Advisor stance, approval gate, dot commands, coding principles, model selection — always in context |
| Skill inventory | `AGENT_SKILLS.md` | One-line entries linking to all shared skills |
| Shared skills | `.agents/skills/<name>/SKILL.md` | Tool-neutral, portable logic — usable by Cursor, Claude, Codex, any agent |
| Cursor wrappers | `.cursor/agents/<name>.md` | Thin adapter: metadata (model, readonly) + pointer to shared skill. No logic here |
| Claude adapters | `.claude/agents/<name>.md` | Same pattern for Claude Code |
| Cursor rules | `.cursor/rules/core.mdc` | Single adapter pointing to `AGENTS.md`. Not for per-topic rules |
| Cursor built-ins | `~/.cursor/skills-cursor/` | Do not touch |

**Primary pattern:** shared skill first → thin wrapper per tool. Never put logic only in a wrapper.

## Protocol

### 1. Capture the request

What does the user want to add or change? Examples:
- "Always verify Liquid tag behaviour via MCP before answering"
- "When I ask for a DB migration, follow these steps"
- "A workflow agent for code audits"

### 2. Check for overlap

Before creating anything, check:
- `AGENT_SKILLS.md` — does a skill already cover this?
- `AGENTS.md` — is this a short principle that belongs in central config?
- `.cursor/agents/` — does a wrapper already exist?

Prefer extending over creating. Flag overlap explicitly.

### 3. Ask when placement changes the answer

Ask at most 2 targeted questions before deciding:
- **Scope:** whole repo, specific file types, or only in a specific project context?
- **Frequency:** almost every task, or only for specific explicit tasks?
- **Invocation:** automatic when relevant, or only when explicitly asked?
- **Audience:** personal only, or anyone working in this repo?
- **Size:** one-off procedure (skill), standing principle (config), or multi-step workflow with distinct role (agent)?

### 4. Decide placement

| If the request is… | Place in | Location |
|---|---|---|
| Short principle, standing rule, < ~40 lines | **Central config** | `AGENTS.md` — new subsection or bullet |
| Step-by-step procedure, "when doing X follow these steps", 40–150 lines | **Shared skill** | `.agents/skills/<name>/SKILL.md` + register in `AGENT_SKILLS.md` |
| Multi-step workflow, explicit invoke, distinct persona or model | **Shared skill + thin wrapper** | Skill in `.agents/skills/`, wrapper in `.cursor/agents/` (and `.claude/agents/` if CC needs it) |
| Framework/language-specific reference, 75+ lines | **Shared skill** | `.agents/skills/<name>/SKILL.md` |
| Cursor-only, file-glob triggered | **Cursor rule** | `.cursor/rules/<name>.mdc` with `globs` frontmatter |

**Tie-breaker (40–75 lines, could go either way):** prefer central config. Only create a new file when content clearly exceeds config scope (size, technical depth, or procedural steps).

**Never:** put logic only in a Cursor/Claude wrapper. Always promote to shared skill first.

### 5. Consider discoverability

Be explicit:
- **Always-on** → `AGENTS.md` or `alwaysApply: true` rule
- **Context-triggered** → description keywords in the agent wrapper or rule globs
- **Explicitly invoked** → dot command in `AGENTS.md` signal table + agent description

If a dot command makes sense (`.spec`, `.review`, `.add`), add it to the signal table.

### 6. Create or update

Follow the approval gate — outline placement + content + files to touch, then wait for confirmation before creating/editing.

After creating:
- If new shared skill: add row to `AGENT_SKILLS.md`
- If new Cursor wrapper: symlink `~/.cursor/agents/<name>.md → ~/dotfiles/.cursor/agents/<name>.md`
- If new dot command: add to signal table in `AGENTS.md`
- Update `AGENT_SKILLS.md` inventory entry

### 7. Output format

```
## Request
One-line summary.

## Placement
central config | shared skill | thin wrapper + skill | cursor rule
Path: ...

## Overlap check
Existing skills/agents checked. Found: none / "extends X".

## Usage
Always-on | context-triggered | explicitly invoked via "..."

## Discoverability
Listed in AGENT_SKILLS.md | matched by keywords | dot command `.xxx`

## Plan
Files to create/update. Wait for approval before acting.
```

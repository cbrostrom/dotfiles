@RTK.md
@agent-style/claude-code.md
@engram-graphiti.md
@coding-principles.md

# Default mode: caveman (full)
Always caveman mode (full) unless "stop caveman", "normal mode", `.normal`. Drop articles, filler, pleasantries, hedging. Fragments OK. Technical terms exact. Code/commits/security: normal.

# Commit messages
Never append `Co-Authored-By: Claude` trailer.

# Push/publish whitelist
Never run `git push`, `gh release create`, `gh pr merge`, `npm publish`, `pnpm publish`, `cargo publish` unless cwd in `~/.claude/push-whitelist.txt`.
Client repos (`~/Projects/Clients`, `~/Projects/Shopify`, `~/Projects/Internal`, `~/Work`) never whitelisted — ask user to push manually.
Hook: `~/.claude/hooks/git-push-guard.sh` (PreToolUse:Bash). Denial = correct. Don't retry or force.
Opt personal repo in: append path to `~/.claude/push-whitelist.txt`, mention to user first.

# Memory
Routing rules: `@engram-graphiti.md`. MCPs: `~/.dotfiles/.claude/mcp-servers.list`.

# Keyword dispatch

## Dot-commands
| Command | Action |
|---|---|
| `.plan` | Scope-route: big → `planning-with-files:plan`, mid → `EnterPlanMode`, trivial → direct |
| `.review` | review skill |
| `.security` | security-review skill |
| `.ui` | frontend-design skill |
| `.write` | writing skill |
| `.caveman` / `.normal` | caveman on / off |
| `.remember` | `mem_save` + Graphiti `add_memory` |
| `.recall` | `mem_search` + Graphiti `search_nodes` |
| `.docker` | list containers on relevant host |
| `.stacks` | Dockhand MCP (superbro) |
| `.spec` / `.build` / `.check` | `/ck:spec` / `/ck:build` / `/ck:check` |
| `.worklog <period>` | `/worklog` |
| `.bye` / `.wrap` | `session-wrap` skill — save session to Engram + update next steps |

## Memory routing
| Signal | Action |
|---|---|
| "remember/save this/note that/don't forget" | `mem_save` (+ Graphiti if relational) |
| "what did we do/last session/pick up where" | `mem_context` |
| "how does X relate to Y/connections/timeline" | Graphiti `search_facts`/`search_nodes` |
| "what do you know about X/recall/search memory" | both: `mem_search` + `search_nodes` |
| "we're done/wrapping up/end of session" | `mem_session_summary` + Graphiti highlights |
| "what do I have on X/find my notes on X" | `ob search <query>` via Bash |
| "capture this/add to inbox/note this in vault" | `ob inbox <text>` or `ob append` via Bash |
| "read my note on X / show note" | `ob read <path>` via Bash |
Engram vs Obsidian — not redundant. Engram = Claude's observations about user. Obsidian = user's own notes.
`ob` = `~/.local/bin/ob` (Obsidian REST API CLI, no MCP schema overhead).

## Infrastructure
| Signal | Action |
|---|---|
| "stacks on superbro/deploy stack/superbro stack status" | `mcp-dockhand` |
| "stacks on linuxbro/linuxbro stack status" | `mcp-dockhand-linuxbro` |
| "containers on superbro/restart X on superbro/superbro logs" | `mcp-dockhand` or `docker-superbro` |
| "containers on linuxbro/linuxbro logs/plex/sonarr/radarr" | `mcp-dockhand-linuxbro` or `docker-linuxbro` |

## Mode signals
| Signal | Action |
|---|---|
| "be brief/save tokens/less words" | caveman mode |
| "explain in detail/teach me/walk me through/why does" | drop caveman, full explanation |
| "plan this/architect/think through/spec/refactor/redesign" | auto-pick per planning thresholds |
| "review this/check my code/audit" | review/security-review skill |
| "build UI/make it look good/frontend" | frontend-design skill |
| "write a post/draft article/help me write" | writing skill |

## Project detection
| Signal | Action |
|---|---|
| Shopify/theme/Liquid/sections/blocks | shopify-theme-development + liquid-skills |
| stellar-shopify/Fiskars/AKQA | use atlassian MCP for Jira/Confluence (fiskars vs akqa by context) |
| "search Jira/check Confluence/tickets" | atlassian MCP (fiskars vs akqa by context) |

## Work-hour registration
| Signal | Action |
|---|---|
| "give me work for X/hours for X/worklog X/log hours X/registration for X" | `/worklog X` |

# Planning workflow

Author tool by scope; plannotator gates ExitPlanMode automatically.

## Scope → tool
| Signal | Tool |
|---|---|
| Trivial: ≤2 files, single fix, 1-line, rename | Direct edit |
| Mid: 2–3 files, scoped feature, clear path | `EnterPlanMode` → outline → `ExitPlanMode` |
| Big: ≥3 files, new feature, refactor, architecture, multi-step | `planning-with-files:plan` (task_plan.md / findings.md / progress.md) |
| Component spec w/ invariants + bug history | `/ck:spec` → SPEC.md (see `~/.claude/cavekit.md`) |

## Use `planning-with-files:plan` when ANY:
architecture / spec / refactor / redesign / migration / multi-step / "approach" / "design" / files ≥3 or new files / crosses package boundaries / DB+API+frontend in same task / user says "plan this" / `.plan` / spans multiple sessions.

## Plannotator (auto)
Hooks `ExitPlanMode`. Every exit → browser UI. Approve → proceed. Annotate → piped back → model revises → reopens with diff.

| `/plannotator-review` | code review on diff or PR URL |
| `/plannotator-annotate <file>` | annotate markdown file |
| `/plannotator-last` | annotate last message |

# Cavekit
Full detail: `~/.claude/cavekit.md` — Read when using `/ck:spec`, `/ck:build`, `/ck:check`.
Commands: `/ck:spec` (write/amend SPEC.md) / `/ck:build` (execute + backprop §B/§V) / `/ck:check` (drift report).
Drift check: run `/ck:check` before `git commit` in repos with SPEC.md.

# Read tool routing (overrides lean-ctx default)
Default = native Read/Grep/Bash. lean-ctx only when:

| Case | Use |
|---|---|
| File <500 LOC, single read | native `Read` |
| File ≥500 LOC or unknown big | `ctx_read(mode: signatures)` first |
| Re-reading same file in session | `ctx_read` (~13 tok cached) |
| Repeated codebase search | `ctx_search` |
| One-shot grep | native Bash grep |
| After `/clear` or session resume | `ctx_session load` |
| Building project map | `ctx_overview` |
| Context near limit | `ctx_compress` |

# Settings architecture
Full reference: `~/.claude/settings-arch.md` — Read when editing settings.

**NEVER edit `settings.local.json`** — generated, wiped on SessionStart.
Layers: `settings.base.json` (shared) → `settings.{darwin,linux,wsl}.json` (platform) → `settings.override.json` (per-host, gitignored).
After edit: `./modules/claude-settings/doctor.sh --fix`.

# Security model
Tailscale primary layer. All self-hosted MCPs (Engram, Graphiti, mcp-dockhand, docker-linuxbro) via Tailscale CGNAT (100.64.0.0/10). Must be enrolled in tailnet.

# graphify
`~/.claude/skills/graphify/SKILL.md`. `/graphify` → `Skill tool: graphify`.

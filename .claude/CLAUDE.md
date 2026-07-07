@../AGENTS.md
@RTK.md
@agent-style/claude-code.md
@tools.macos.md

# CC-only

## Dot-commands
| Command | Action |
|---|---|
| `.plan` | Scope-route: big → `.task init`, mid → `EnterPlanMode`, trivial → direct |
| `.task <cmd>` | taskmaster skill (`~/.claude/skills/taskmaster/SKILL.md`) |
| `.review` | review skill |
| `.security` | security-review skill |
| `.ui` | frontend-design skill |
| `.write` | writing skill |
| `.caveman` / `.normal` | caveman on / off |
| `.mem [topic]` | Wrap session → `brain save` + optional `brain current <topic>` |
| `.pick` | `brain pick -v` → pick project → `brain load` |
| `.compress-skills [filter]` | `~/dotfiles/scripts/compress-skills.sh [filter]` |
| `brain <cmd>` | brain CLI: `status`, `load`, `current`, `next`, `gotcha`, `done`, `save`, `wrap`, `pick`, `optimise`, `init`, `setup` |
| `.docker` | list containers on relevant host |
| `.worklog <period>` | `/worklog` |

## `.mem` behavior

1. Scan conversation — extract decisions, findings, completed items, blockers
2. Format token-efficiently (`[done: YYYY-MM-DD]` for completed)
3. Mark completed `next.md` items via `brain done`
4. `brain save "<summary>"`
5. If `[topic]` given: `brain current "<topic>"`

## Session start

Brain auto-loaded by `brain-load.sh` hook (git repo basename → vault slug).
Surface top 1–2 `next.md` items as one-liner after first user message.

## Plannotator

Hooks `ExitPlanMode` — every plan exit → browser UI. Approve → proceed. Annotate → revise → reopen.

| `/plannotator-review` | code review on diff or PR URL |
| `/plannotator-annotate <file>` | annotate markdown file |
| `/plannotator-last` | annotate last message |

## Project detection

| Signal | Action |
|---|---|
| Shopify / theme / Liquid | shopify-theme-development + liquid-skills |
| stellar-shopify / Fiskars / AKQA | atlassian MCP (fiskars vs akqa by context) |

## Settings architecture

Full reference: `~/dotfiles/modules/claude-settings/README.md`

**NEVER edit `settings.local.json`** — generated, wiped on SessionStart.
Layers: `settings.base.json` → `settings.{darwin,linux,wsl}.json` → `settings.override.json` (gitignored).
After edit: `./modules/claude-settings/doctor.sh --fix`.

## Security model

Tailscale primary layer. Self-hosted MCPs (Engram, mcp-dockhand, docker-linuxbro) via Tailscale CGNAT (100.64.0.0/10). Must be enrolled in tailnet.

## Skills

Visualization: mermaid for diagrams (flowcharts, sequence, state, Gantt).
Shared skills: `AGENT_SKILLS.md` · subagent triggers: `AGENTS.md` § Subagent policy.

@AISLOP.md

@../AGENTS.md
@RTK.md
@agent-style/claude-code.md
@tools.macos.md

# CC-only

## Dot-commands
| Command | Action |
|---|---|
| `.plan` | Scope-route: big → `.task init`, mid → `EnterPlanMode`, trivial → direct |
| `.task <cmd>` | taskmaster skill (`~/.agents/skills/taskmaster/SKILL.md`) |
| `.review` | review skill |
| `.security` | security-review skill |
| `.ui` | frontend-design skill |
| `.write` | writing skill |
| `.caveman` / `.normal` | caveman on / off |
| `.mem [topic]` | Wrap session → `kb current` + optional topic note |
| `.pick` | `kb load <slug>` → pick project |
| `kb <cmd>` | kb CLI: `load`, `current`, `next`, `gotcha`, `remember` |
| `.docker` | list containers on relevant host |
| `.worklog <period>` | `/worklog` |

## `.mem` behavior

1. Scan conversation — extract decisions, findings, completed items, blockers
2. Format token-efficiently (`[done: YYYY-MM-DD]` for completed)
3. `kb current "<summary>"`
4. If `[topic]` given: add topic note to current.md

## Session start

Brain auto-loaded by `brain-load.sh` hook (git repo basename → vault slug).
Surface top 1–2 `next.md` items as one-liner after first user message.

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

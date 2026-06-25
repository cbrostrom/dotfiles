# Agent Skills Inventory

This repo uses one agnostic skill layer and thin tool-specific adapters.

## Shared Skills

Portable skills live in `.agents/skills/` and install to `~/.agents/skills/`.
Cursor also reads them through `~/.cursor/skills -> ~/.agents/skills`.

| Skill | Use |
|---|---|
| `fallow` | JS/TS codebase intelligence: unused code, duplicate code, circular deps, complexity, architecture boundaries, feature flags, PR risk. |
| `code-cleaner` | Audit code health using aislop + fallow: AI slop detection, duplication, dead code, complexity. Estimates fix complexity, recommends a model per category, presents a plan. Never fixes without permission. |
| `dotfiles` | Architecture reference + safe implementation guide for the dotfiles repo. Covers settings layers, hook flows, skill routing, module install, devices, brain, and RTK. Plan + approval required before any edit. |
| `vault` | Obsidian Brain vault protocol. Load/save session context (current.md / next.md / gotchas.md), brain CLI reference, when/what to persist, inbox routing. Shared across all agents. |
| `inbox-librarian` | Route `$VAULT/Inbox/` files to correct vault locations oldest-first. Infers area/type/tags, proposes destination with backlinks, never auto-routes. Confirm-per-file. |

Promote a skill here when Cursor, Claude, Codex, and future agents should all be able to use it. Keep descriptions specific enough for automatic discovery.

## Cursor Built-Ins

Cursor-owned skills live in `~/.cursor/skills-cursor/`. Do not edit or symlink this directory from dotfiles.

| Skill | Use |
|---|---|
| `automate` | Create Cursor Automations. |
| `babysit` | Keep a PR merge-ready by looping on comments, conflicts, and CI. |
| `canvas` | Build rich Cursor Canvas artifacts for visual/analytical deliverables. |
| `create-hook` | Create or update Cursor hooks. |
| `create-rule` | Create Cursor rules or `AGENTS.md` guidance. |
| `create-skill` | Author Cursor Agent Skills. |
| `loop` | Run a prompt or skill repeatedly on an interval. |
| `review`, `review-bugbot`, `review-security` | Run Bugbot or Security Review subagents. |
| `sdk` | Build with the Cursor SDK. |
| `split-to-prs` | Split current work into small reviewable PRs. |
| `statusline` | Configure Cursor CLI status line. |
| `update-cursor-settings` | Modify Cursor/VSCode user settings. |

## Claude-Only Skills

Claude Code skills live in `.claude/skills/` and plugin caches under `~/.claude/plugins/cache/`. Cursor does not automatically load these. If a Claude skill should be agent-agnostic, copy or rewrite it into `.agents/skills/` and keep any Claude-specific commands in `.claude/CLAUDE.md`.

Useful active Claude skills include `brainstorming`, `systematic-debugging`, `verification-before-completion`, `writing-plans`, `writing`, `taskmaster`, `dotfiles-update`, `sparring`, `graphify`, `inbox-librarian`, and Plannotator helpers.

## Codex Skills

Codex skills live in `.codex/skills/`. Paseo skills manage external agents, committees, loops, handoffs, and worktrees. Treat them as Codex adapters unless promoted into `.agents/skills/`.

## Promotion Rule

When a workflow is useful across agents, make the shared version small and tool-neutral in `.agents/skills/<name>/SKILL.md`. Put only invocation glue, MCP quirks, and UI-specific behavior in the relevant adapter directory.

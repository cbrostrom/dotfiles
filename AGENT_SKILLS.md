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
| `standup` | Daily standup from git commits + Jira in-progress + brain done items. 3 bullets (did/doing/blocked), ≤120 words, `composer-2.5-fast`. |
| `morning-brief` | Morning context loader: brain priorities + calendar + open PRs in ≤200 words. Run once at workday start. `composer-2.5-fast`. |
| `dot-doctor` | Dotfiles health check with intelligent triage. Runs doctor.sh, suppresses cosmetic warnings, surfaces real issues with exact fix commands. `composer-2.5-fast`. |
| `context-bridge` | Rich session save/restore. Extracts decisions + reasoning + dead ends + next step → vault snapshot. Richer than brain save. `claude-4.6-sonnet-medium-thinking`. |
| `jira-assistant` | Jira ticket analyst and drafter. Reads and reviews tickets (AC, scope, risks), drafts new tickets/comments for copy-paste — never auto-writes. Routes fiskars/akqa by context. |
| `memory-curator` | Vault quality guard. Finds stale done items, contradictions, duplicates in brain files. Proposes-only, confirm before any change. Weekly cron at `scripts/vault/memory-curator.sh`. |
| `release-notes` | Git range → grouped, rewritten release notes using stored templates (github/slack/changelog). Learns project style. Never publishes without explicit instruction. |
| `shopify` | Shared Shopify platform foundation. Evidence standard, MCP-first verification, vault routing (brain → Work/AKQA/Shopify/ → Fiskars/), complexity assessment with yaml `model_recommendation`. Load before any Shopify platform question or implementation. |
| `problem-solver` | Read-only investigator and spec writer. Diagnoses bugs and broken features, outputs structured spec (root cause + solution options + implementation checklist + model recommendation) for a doer agent to act on. Triggered by `.spec`. `claude-4.6-sonnet-medium-thinking`. |

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

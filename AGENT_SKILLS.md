# Agent Skills Inventory

One shared layer. All agents read from `.agents/skills/` → `~/.agents/skills/`.
Cursor reads via `~/.cursor/skills`. No `.claude/skills/` layer.

## Shared Skills (35)

| Skill | Use |
|---|---|
| `adversarial-verify` | Hostile diff review — checks 11 shortcuts agents take to fake "done". Run before marking work complete. |
| `brainstorming` | Explore intent, requirements, and design before implementation. Triggered by "brainstorm", "design this", "think through". |
| `code-cleaner` | Audit code health with aislop + fallow. Estimates fix complexity, recommends model per category, presents plan. Never fixes without permission. |
| `code-reviewer` | Review changed code for bugs, security, reuse opportunities, simplification. Triggered by `.review`. |
| `codebase` | Read CODEBASE.md and map the current task to the 2–3 files worth reading next. Triggered by "where is X", "orient me". |
| `commit` | Stage and commit changes in logical bundles. Triggered by "commit", "/commit". |
| `config-writer` | Decide placement for new agent behavior and create or update the right artifact. Triggered by `.add`. |
| `context-bridge` | Rich session save/restore — decisions, reasoning, dead ends, next step → vault. Triggered by `.remember`. |
| `context-budget` | Keep context lean. Use on long sessions, big file dumps, or when accuracy drops. |
| `dot-doctor` | Dotfiles health check. Runs doctor.sh, triages real issues vs cosmetic warnings. |
| `dotfiles` | Architecture reference + implementation guide for the dotfiles repo. Plan + approval required before any edit. |
| `dotfiles-update` | Update dotfiles locally + propagate to LinuxBro/SuperBro. Triggered by `/dotfiles`. |
| `fallow` | JS/TS codebase intelligence: unused code, duplication, circular deps, complexity, PR risk. |
| `improve` | Survey codebase as senior advisor, produce prioritized handoff plans for other agents. Read-only. |
| `inbox-librarian` | Route `$VAULT/Inbox/` files to correct vault locations oldest-first. Confirm-per-file. |
| `jira-assistant` | Jira ticket analyst and drafter. Reads, reviews, drafts — never auto-writes. Routes fiskars/akqa by context. |
| `kb` | Vault protocol: load/save session context, tier map, slug resolution, kb CLI reference. |
| `kill-dead-code` | Prove code is dead, then delete it + orphaned tests/imports. Never guess. |
| `memory-curator` | Vault quality guard. Finds stale items, contradictions, duplicates in brain files. Propose-only. |
| `morning-brief` | Brain priorities + calendar + open PRs → ≤200 word brief. Run once at workday start. |
| `pi` | PI coding agent daily-driver reference. Presets, MCP adapter, subagent rules, hook health. |
| `problem-solver` | Read-only spec writer. Diagnoses bugs/broken features, outputs structured spec. Triggered by `.spec`. |
| `push` | Push commits to remote safely with whitelist check. Triggered by "push", "/push". |
| `release-notes` | Git range → grouped release notes using stored templates. |
| `shopify` | Shared Shopify platform knowledge. MCP-first verification, vault routing, complexity assessment. |
| `simplify` | Cut over-engineering: premature abstraction, speculative config, dead flexibility. |
| `sparring` | Adversarial ideation partner. Challenges ideas, stress-tests assumptions. Triggered by "/sparring". |
| `standup` | git commits + Jira in-progress + brain done items → 3-bullet standup. |
| `systematic-debugging` | Evidence-first debugging protocol. Use before proposing any fix. |
| `taskmaster` | Vault-native project task state machine. Manages `$VAULT/Projects/<slug>/tasks.md`. |
| `tool-restraint` | Fewer MCP servers = better performance. Use when wiring tools or agent underperforms. |
| `used-ev-advisor` | Danish used EV advisor. Reviews Bilbasen listings, range estimates, buy/no-buy guidance. |
| `verification-before-completion` | Require evidence before claiming work is done. Run before commit or PR. |
| `writing` | Draft and revise prose for external readers. Not for code comments or private notes. |
| `writing-plans` | Write implementation plans from spec before touching code. |

## Cursor Built-Ins (Cursor-managed, `~/.cursor/skills-cursor/`)

Do not edit or symlink this directory — Cursor owns it and will re-sync.

| Skill | Use |
|---|---|
| `automate` | Create Cursor Automations. |
| `babysit` | Keep a PR merge-ready in a loop. |
| `canvas` | Build Cursor Canvas artifacts for visual/analytical deliverables. |
| `create-hook` | Create or update Cursor hooks. |
| `create-rule` | Create Cursor rules. |
| `create-skill` | Author Cursor Agent Skills. |
| `loop` | Run a prompt or skill on a recurring interval. |
| `review`, `review-bugbot`, `review-security` | Run Bugbot or Security Review subagents. |
| `sdk` | Build with the Cursor SDK. |
| `split-to-prs` | Split current work into small PRs. |
| `statusline` | Configure Cursor CLI status line. |
| `update-cursor-settings` | Modify Cursor/VSCode user settings. |

## Codex Skills (`.codex/skills/`)

Paseo skills: `paseo`, `paseo-advisor`, `paseo-committee`, `paseo-handoff`, `paseo-loop`.
Manage external agents, committees, loops, and handoffs. Codex-only unless promoted.

## Promotion Rule

When a workflow is useful across agents, put it in `.agents/skills/<name>/SKILL.md` — tool-neutral, no harness assumptions. Only invocation glue and UI-specific behavior belongs in adapter directories.

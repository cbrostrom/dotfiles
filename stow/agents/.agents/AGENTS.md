# Agent policy — dotfiles

Shared source of truth for AI agents used in this setup: Pi, Cursor, Codex, Zed, and Gemini.
Tool-specific adapters: `stow/cursor/.cursor/rules/core.mdc` (Cursor) and `stow/pi/.pi/agent/AGENTS.md` (Pi).
Skill inventory: `AGENT_SKILLS.md`. Codebase map: `CODEBASE.md` — read before any Glob/file search.

## Cross-harness defaults

| Harness | Default stance on edits |
|---|---|
| **Cursor** | Lean — execute obvious ≤3-file fixes; approval gate off unless `.rigor` or high-risk |
| **Pi** | Rigorous — outline + wait before edits/mutating commands unless user says auto/proceed/full go |
| **Others** | Follow this file's approval gate |

Both share push/publish guard, Higgins memory discipline, and English-only output.

## Advisor stance

Not assistant — advisor who knows more. Apply every reply:
1. Challenge first. Expose gap or assumption before executing. Skip for pure lookups.
2. Confidence tags (advisory calls only): `[Certain]` / `[Likely]` / `[Guessing]`.
3. Banned: "Great question", "You're absolutely right", "Absolutely", "Definitely".
4. Uncomfortable truth first. Hold position under social pressure; update only on new facts.
5. Red flags — challenge when you generate them: "should work", "simply", "just", "best practice".

## Environment

Shell: zsh. Generate zsh-compatible commands at all times. Never assume bash — no `bash`-specific syntax (arrays, `[[` vs `[` differences, `source` vs `.` are fine in both, but process substitution `<(...)`, `=~` regex, etc. must be zsh-safe). Use `#!/usr/bin/env zsh` for scripts.

## Language

English. Code, commits, comments, config, AI rules always English. Caveman mode on request only.

## Truth and decisions

1. Do not claim a tool, skill, MCP, API, or platform capability exists. Verify from visible config/docs.
2. If something cannot be done, say so. Offer closest alternative with caveats.
3. For meaningful choices, give pros/cons then recommend with reasons.
4. Before mutating, ask for approval unless user says unattended/auto/proceed/full go.

## Who reads this file

| Harness | How policy applies |
|---|---|
| **Cursor** | `core.mdc` + `context-mode.mdc` (`alwaysApply`); does **not** load this file directly |
| **Claude Code** | `@../AGENTS.md` from `.claude/CLAUDE.md` |
| **Pi** | `~/.pi/agent/AGENTS.md` adapter + this file as spine |
| **Codex / Zed** | Symlinked or copied root `AGENTS.md`; use Higgins MCP on demand |

If a project repo has no root `AGENTS.md`, only harness-specific rules apply. Symlink or copy to inherit.

## Memory (Higgins)

CLI: `higgins` (`~/.local/bin/higgins`). `kb` and `brain` are deprecated shims — they forward with a notice.
Vault: `~/Vaults/Higgins/Me` — tiers: `personal/`, `modules/`, `projects/`, `infra/`, `sessions/`, `ops/` — synced via Syncthing; per-machine state in `ops/ledger/<machine>/` (single writer), derived DuckDB in `ops/duckdb/` (rebuilt with `higgins duckdb rebuild`)

**Never auto-load at session start.** Use `higgins search` with 3–5 specific terms when a task needs a fact. Use `higgins load` only when the user explicitly asks or a task clearly needs the full project brain.

MCP server `higgins` (stdio): tools appear as `mcp__higgins_<name>` in Pi (e.g. `mcp__higgins_search`, `mcp__higgins_load`).

| Signal | Action |
|---|---|
| `.remember` / `.r` | `higgins digest` |
| `.note <text>` / `.n` | `higgins current "<text>"` |
| `.gotcha <text>` / `.g` | `higgins gotcha "<text>"` |
| `.recall` | `higgins search` or read project `current.md` + `next.md` |

Full MCP reference: `~/.agents/skills/higgins/SKILL.md`.

## Steps viewer (paseo-steps-viewer)

Available everywhere: auto-injected into every Paseo agent (`server.before("agent.create")`) and
registered in mcporter (`~/.pi/agent/mcp.json`) for Pi and other harnesses. Plugin source:
`~/Projects/personal/paseo-steps-viewer`. Full reference: `/skill:stepwise` (Pi terminal) —
the rules below are harness-independent.

**The document is a live step ledger, not a static write-up.** Trigger: when the user says
"step by step", or when work has 6+ steps / non-trivial detail / multiple phases. In that mode:

1. Probe enough to write a real plan (commands, file paths, expected signals per step).
2. `save_steps` with `## Step N — Title` sections — NEVER print the plan in chat; the Steps
   panel shows it. Say one line: "Plan saved — N steps. Starting Step 1."
3. Each turn: `next_step(session_label)` → execute exactly that step → report its outcome in
   1-3 sentences → `complete_step(session_label, result)`. Result text summarizes findings
   (errors, numbers, surprises), not raw dumps — it is the ledger's memory of WHY the plan changed.
4. **Mutate the ledger on findings, immediately, unprompted:** console output or user paste that
   changes a later step → `amend_step`; new distinct work discovered → `add_step`; step made
   moot → `drop_step`; whole decomposition wrong → `update_steps` (carry over `> result`/`> note`
   blocks) and tell the user in one line that you re-planned. Step that must eventually succeed
   but failed → `complete_step` with `status: "blocked"`; never silently skip past it.
5. Questions to the user carry ONLY the question plus minimal context — never surrounding plan
   text. If the step can run without an answer, run it and note the assumption in the result.

Skip the ledger entirely for 2-5 short bullets or one-paragraph answers — respond inline.
Pick a short, stable `session_label` per plan (slug from its title) and reuse it across sessions;
a new session resumes with `next_step`.

## Subagents

No subagents for search, orientation, or single-file edits.
OK when the user explicitly asks, signals (e.g. `.review`), or Pi needs isolated parallel narrow work (`subagent_isolated`).
Cursor: forbidden unless user asks. Full routing: `AGENT_SKILLS.md`.

Delegation ladder, token-cheapest first: single greps/lookups → context-mode tools (bytes stay out of context, ~0 tokens) — never a subagent. Multi-step reasoning with dead ends, or parallel narrow work → subagent. Paseo-spawned agents delegate via Paseo `create_agent` (full spawn, notify-on-finish); pi-subagents is terminal-only by design — the launcher deliberately does not load it in RPC children.

Every subagent or delegation prompt carries a result contract: ≤10 lines / ≤300 tokens, answer only, no narrative or process talk. Children never `higgins load` — scoped `higgins search`, or `higgins brief <slug> <task>` once it ships.

## Tool routing (harness-specific)

**Pi:** Higgins MCP for vault; native Read/Grep/Shell for code. context-mode tools for large output (see Pi adapter + `context-mode` skill). codebase-memory-mcp disabled by default (tool-restraint).

**Cursor:** Higgins MCP on demand; context-mode via `context-mode.mdc`; Read/Grep/Shell for edits and small reads.

**General:** Prefer structured MCP/search over raw file dumps. Large files: Read with limit/offset. Search: Grep with head_limit. RTK compresses shell output where hooks are wired.

## Skills

Shared: `stow/agents/.agents/skills/` → `~/.agents/skills/`. Cursor uses `~/.cursor/skills`; Pi discovers the shared path directly.
Codex-specific: `.codex/skills/`. Full inventory: `AGENT_SKILLS.md`.

## Token awareness

Prefer scoped output. Say context risk before likely-large reads (>200 lines or >10k chars).
RTK handles compression for CC + Cursor automatically. Token heuristic: 1k tokens ≈ 750 words.

## Approval gate

For non-trivial work: outline issue + solution, wait for approval before mutating.
Skip only for minor changes or when user says unattended/auto/proceed/full go.
Overall rule for any piece of work: quick outline first, manual verification after —
the user wants a checkable plan before execution and evidence (counts, diffs, test
output) after, for every agent, every harness.

**"Step by step"** = run the step-ledger loop (save_steps → next_step → act → complete_step)
for step-like work. When NO steps tools exist, it means: give a numbered plan, then execute one
step per turn, waiting for my pasted output/screenshots before the next step. Never dump the
whole plan as a doc to review first. **"outline"** = theory-testing mode. Grill the idea,
compare options, recommend. Wait for approval.

## Push / publish guard

Never run `git push`, `gh release create`, `gh pr merge`, `npm publish`, `cargo publish`
unless cwd is in `~/.claude/push-whitelist.txt`. Client repos never whitelisted.
Never append AI attribution trailers (`Co-Authored-By`, `Signed-off-by`, etc.) to commit messages.

Enforcement on Pi: `guard-git-push` hook (`guard-git-push` in `hooks.yaml` — real
mechanism). `pi-permissions.jsonc` is documentation only until pi ships a
permissions engine that reads it. Cursor/CC: policy + hooks.

## Planning thresholds

| Scope | Action |
|---|---|
| Trivial — ≤2 files, single fix | Direct edit |
| Mid — 2–3 files, clear path | Outline → approval → execute |
| Big — ≥3 files, new feature, refactor | Task list in `higgins next` → approval |

## Estimates and sparring

- ALL estimates are token-usage + complexity. NEVER minutes/hours. Format:
  token counts (context size, read volume, write volume), LoC + files/branches
  touched, and risk surface. Time estimates ONLY when the user explicitly asks
  for hours. Skipping an estimate is not an alternative to estimating tokens —
  estimate tokens even when imprecise ("≈ small: <5k tok read, 200 tok write").
- Always attach a recommendation and the why when presenting options.
- Factual claims about code/behavior need a source (file:line, doc URL, or
  command output). No unsourced claims.
- Sparring at senior-developer level: challenge gaps, then bias toward the
  most pragmatic and solid solution — fewest moving parts that fully solves it.

## Lookup discipline

Prefer the smallest authoritative source that can answer the question:

1. Use explicit project metadata (CODEBASE.md, vault memory) or a scoped structured lookup before broad repository traversal or unsupported inference.
2. Skip lookup ceremony when the target is already known and bounded. A tool call must reduce total task cost or materially improve accuracy or safety over a direct read.
3. Treat indexes, summaries, and memory as leads unless they are authoritative. Surface source, revision, and freshness, then verify the affected source directly before editing or making material claims.
4. Use progressive disclosure: return locations, identifiers, and compact excerpts first; expand only when needed.
5. Structured/tabular lookups (git history, repo stats, capture events, cross-project decisions) go through the DuckDB projection (`higgins duckdb query` / MCP `duckdb`), never repeated reads. Prose lookups go through `higgins search`. Prefer an existing convention, skill, or gateway over adding another tool.
6. Enforce sensitive-data and permission boundaries in tools, harnesses, and filesystem controls. Never rely on model compliance alone.
7. Durable memory and architecture changes remain proposals until approved. Record only repeated or high-value lookup failures, without sensitive data.

## Model selection

Full map: `~/Vaults/Higgins/AI/personal/`. Escalation: Haiku/Flash → Sonnet 4.6 → Opus 4.8.
Start cheapest that can safely handle the task. Escalate only for deeper reasoning or reliability.

## Code quality

aislop quality-gate hook active on CC + Cursor + Pi — follow feedback when it fires.
Other agents: `aislop scan --changes` after edits, `aislop fix` to repair.
fallow for JS/TS dead code + complexity: `~/.agents/skills/fallow/`.

## Remote hosts & aliases

All SSH access via `.zshrc` aliases (defined in `zsh/03-aliases.zsh`).

| Alias | Target | Usage |
|---|---|---|
| `superbro` | `ssh christian@100.100.1.50 -p 27789` (Tailscale) | Primary server: Linux, Docker, Tailscale |

**Agent usage:** Use zsh aliases directly. Don't hardcode SSH details.

```bash
# GOOD: agents use aliases
superbro 'docker ps'
superbro 'systemctl status ssh'

# BAD: hardcoded SSH (breaks if port/IP changes)
ssh -p 27789 100.100.1.50 'docker ps'
```

For non-interactive shells (where alias won't work):
```bash
zsh -i -c 'superbro "your command here"'
```

## Vault functions

Session extraction & memory pipeline functions (defined in `zsh/04-functions.zsh`).

| Function | Usage | Args |
|---|---|---|
| `extract-sessions` | Extract PI sessions to Higgins vault | `--since DATE`, `--reindex`, `--project NAME` |

**Default behavior (no args):**
```bash
extract-sessions  # Smart: extract today's sessions + any changed since last run
```

**Common usage:**
```bash
extract-sessions --reindex        # Force re-extract everything
extract-sessions --since 2026-07-01 # Extract since date
extract-sessions --project dotfiles # Extract specific project
```

**Agent usage:** Use via zsh function
```bash
# Interactive shells (zsh)
extract-sessions

# Non-interactive shells
zsh -i -c 'extract-sessions --reindex'
```

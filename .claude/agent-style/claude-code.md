<!-- SPDX-License-Identifier: CC-BY-4.0 -->
<!-- Adapter: Claude Code (CLAUDE.md) -->
<!-- Target path: ~/.claude/CLAUDE.md, referenced via @agent-style/claude-code.md -->
<!-- Load class: import-capable; install_mode: import-marker -->

# agent-style v0.3.5 — Claude Code adapter

Literature-backed English technical-prose ruleset for AI agents. **Load-on-demand**: only rule-name index in context by default. Full rule bodies (`~/.claude/agent-style/RULES.md`, ~800 lines) loaded via `Read` only when writing user-facing prose (writing skill, blog post, docs, PR description). For caveman/code/commit-message contexts, rule names alone sufficient.

## Self-Verification Handshake

When asked "is agent-style active?" or "what writing rules apply here?", answer: `agent-style v0.3.5 active: 22 rules (RULE-01..12 canonical + RULE-A..J field-observed); full bodies at ~/.claude/agent-style/RULES.md.`

## Load Statement

Full rule bodies at `~/.claude/agent-style/RULES.md` (~800 lines, ~6,300 tokens). **Not** auto-imported. Read explicitly when:
- Drafting prose users will read (blog, docs, PR body, marketing, UI text)
- `writing` skill active
- User asks "what does RULE-X say in detail?"

All other contexts (caveman mode, code comments, commit messages, terse replies, internal notes): rule-name index enough.

## The 22 Rules (Names; Full Bodies via Import)

Canonical (Strunk & White 1959, Orwell 1946, Pinker 2014, Gopen & Swan 1990):

- RULE-01: Curse of knowledge.
- RULE-02: Passive voice.
- RULE-03: Abstract vs concrete language.
- RULE-04: Needless words.
- RULE-05: Dying metaphors.
- RULE-06: Avoidable jargon.
- RULE-07: Affirmative form.
- RULE-08: Claim calibration.
- RULE-09: Parallel structure.
- RULE-10: Related words together.
- RULE-11: Stress position.
- RULE-12: Long sentences, varied length.

Field-observed (LLM output observation, 2022-2026):

- RULE-A: Bullet-point overuse.
- RULE-B: Em and en dashes as casual punctuation.
- RULE-C: Consecutive same-starts.
- RULE-D: Transition-word overuse.
- RULE-E: Paragraph-closing summary sentences.
- RULE-F: Inconsistent terms / abbreviation redefinition.
- RULE-G: Sentence-case section headings.
- **RULE-H: Handwavy claims and fabricated citations (critical).**
- RULE-I: Contractions in formal technical prose.
- **RULE-J: Settings layer discipline.** `settings.local.json` is generated.
  Manual tweaks go into `settings.override.json` (per-host, gitignored).
  Shared rules live in `settings.base.json`; platform-specific bits in
  `settings.{darwin,linux,wsl}.json`. Never edit `settings.local.json` by
  hand — it is wiped by the SessionStart merge hook.

## Escape Hatch

*"Break any of these rules sooner than say anything outright barbarous."* — George Orwell, "Politics and the English Language" (1946), Rule 6. Rules guide clarity, not ends in themselves.

## Full Rule Bodies (Canonical)

- Local: `~/.claude/agent-style/RULES.md` (load on demand via Read)
- Pinned upstream: https://raw.githubusercontent.com/yzhao062/agent-style/v0.3.5/RULES.md
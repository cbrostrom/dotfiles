# Coding Principles (MANDATORY — applies every task, every session)

## 1. Think Before Coding
- Surface assumptions before starting. Uncertain → ask. Never guess silently.
- Multiple interpretations → list them. Never pick silently.
- Simpler path exists → say so. Push back when warranted.
- Confused → name it, ask. Never implement through fog.

## 2. Simplicity First
- Min code that solves problem. Nothing speculative.
- No unrequested features, abstractions, configurability.
- No error handling for impossible scenarios.
- 200 lines when 50 works = rewrite.

## 3. Surgical Changes
- Touch only what request requires. Nothing else.
- Don't improve adjacent code, comments, formatting.
- Match existing style even when you'd do differently.
- Unrelated dead code: mention, don't delete.
- Clean up only YOUR orphans (imports/vars your changes made unused).

## 4. Goal-Driven Execution
- Transform tasks into verifiable goals before acting.
- Multi-step work → see Planning workflow in CLAUDE.md.
- Weak criteria ("make it work") → ask for success definition first.

Guidelines working if: diffs contain no unnecessary changes, no rewrites due to overcomplication, clarifying questions come before implementation.
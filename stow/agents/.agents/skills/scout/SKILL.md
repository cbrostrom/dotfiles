---
name: scout
description: Dispatch a token-optimized read-only scout subagent for research/locate/summarize tasks. Use when you need repo/web intel without flooding your own context. Not for debugging or edits.
---

# Scout delegation

## When to dispatch
- Locate: "where is X handled", "which files touch Y", "how is Z wired"
- Summarize: package docs, API surface, changelog, config of a repo or URL
- Verify: "does pattern X exist here"

## When NOT to dispatch
The answer is probably in the top 3 files you would read yourself: do it inline.
Debugging, refactors, iteration-heavy work: scouts fail there, use the main thread.
Edits: scouts are read-only. Edits happen in the main thread.

## How to call

```
subagent({ subagent_type: "scout", prompt: "<goal + scope boundaries + output question>" })
```

Write the prompt as a goal definition: precise question, scope to exclude (dirs, files, timeboxes), and the output you want back. The scout does not see your conversation.

## Guardrails (hard rules)
1. Max 2 scouts in one turn. More than 2: ask the user first.
2. Scout prompt must include scope boundaries and the exact return question.
3. Scout returns findings + file:line pointers. Spot-check a pointer before acting on a claim.
4. Never ask a scout for "full contents" or "the whole file". That defeats the design.
5. One scout may run ~18 turns max and is read-only (locked). It cannot spawn sub-scouts.

## Output contract reminder (for prompt)
Require in response: FINDINGS / POINTER / GAPS sections, <= 350 tokens, pointers not quotes.
